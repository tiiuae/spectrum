// SPDX-License-Identifier: EUPL-1.2
// SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>

#include "ch.h"
#include "net-util.h"

#include <assert.h>
#include <err.h>
#include <errno.h>
#include <net/if.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdnoreturn.h>
#include <unistd.h>

#include <sys/un.h>

#include <linux/if_tun.h>

static int setup_tap(const char *bridge_name, const char *tap_prefix)
{
	int fd;
	char tap_name[IFNAMSIZ];

	// We assume ≤16-bit pids.
	if (snprintf(tap_name, sizeof tap_name, "%s%d",
		     tap_prefix, getpid()) == -1)
		return -1;
	if ((fd = tap_open(tap_name, IFF_NO_PI|IFF_VNET_HDR|IFF_TUN_EXCL)) == -1)
		goto out;
	if (bridge_add_if(bridge_name, tap_name) == -1)
		goto fail;
	if (if_up(tap_name) == -1)
		goto fail;

	goto out;
fail:
	close(fd);
	fd = -1;
out:
	return fd;
}

static int client_net_setup(const char *bridge_name)
{
	return setup_tap(bridge_name, "client");
}

static int router_net_setup(const char *bridge_name, const char *router_vm_name,
			    const uint8_t mac[6], struct ch_device **out)
{
	int e, fd = setup_tap(bridge_name, "router");
	if (fd == -1)
		return -1;

	e = ch_add_net(router_vm_name, fd, mac, out);
	close(fd);
	if (!e)
		return 0;
	errno = e;
	return -1;
}

static int router_net_cleanup(pid_t pid, const char *vm_name,
			      struct ch_device *vm_net_device)
{
	int e;
	char name[IFNAMSIZ], newname[IFNAMSIZ], brname[IFNAMSIZ];

	if ((e = ch_remove_device(vm_name, vm_net_device))) {
		errno = e;
		return -1;
	}

	// Work around cloud-hypervisor not closing taps it's no
	// longer using by freeing up the name.
	//
	// We assume ≤16-bit pids.
	snprintf(name, sizeof name, "router%d", pid);
	snprintf(newname, sizeof newname, "_dead%d", pid);
	snprintf(brname, sizeof brname, "br%d", pid);

	if (bridge_remove_if(brname, name) == -1)
		warn("removing %s from %s", name, brname);

	if (if_down(name) == -1)
		return -1;
	return if_rename(name, newname);
}

static int bridge_cleanup(pid_t pid)
{
	char name[IFNAMSIZ];
	snprintf(name, sizeof name, "br%d", pid);
	return bridge_delete(name);
}

static noreturn void exit_listener_main(int fd, pid_t pid,
					const char *router_vm_name,
					struct ch_device *router_vm_net_device)
{
	// Wait for the other end of the pipe to be closed.
	int status = EXIT_SUCCESS;
	struct pollfd pollfd = { .fd = fd, .events = 0, .revents = 0 };
	while (poll(&pollfd, 1, -1) == -1) {
		if (errno == EINTR || errno == EWOULDBLOCK)
			continue;

		err(1, "poll");
	}
	assert(pollfd.revents == POLLERR);

	if (router_net_cleanup(pid, router_vm_name,
			       router_vm_net_device) == -1) {
		warn("cleaning up router tap");
		status = EXIT_FAILURE;
	}
	if (bridge_cleanup(pid) == -1) {
		warn("cleaning up bridge");
		status = EXIT_FAILURE;
	}

	exit(status);
}

static int exit_listener_setup(const char *router_vm_name,
			       struct ch_device *router_vm_net_device)
{
	pid_t pid = getpid();
	int fd[2];

	if (pipe(fd) == -1)
		return -1;

	switch (fork()) {
	case -1:
		close(fd[0]);
		close(fd[1]);
		return -1;
	case 0:
		close(fd[0]);
		exit_listener_main(fd[1], pid, router_vm_name,
				   router_vm_net_device);
	default:
		close(fd[1]);
		return 0;
	}
}

struct net_config {
	int fd;
	char mac[6];
};

struct net_config net_setup(const char *router_vm_name)
{
	struct ch_device *router_vm_net_device = NULL;
	struct net_config r = { .fd = -1, .mac = { 0 } };
	char bridge_name[IFNAMSIZ];
	pid_t pid = getpid();
	// We assume ≤16-bit pids.
	uint8_t router_mac[6] = { 0x0A, 0xB3, 0xEC, 0x80, pid >> 8, pid };

	memcpy(r.mac, router_mac, 6);
	r.mac[3] = 0x00;

	if (snprintf(bridge_name, sizeof bridge_name, "br%d", pid) == -1)
		return r;

	if (bridge_add(bridge_name) == -1)
		goto out;
	if (if_up(bridge_name) == -1)
		goto fail_bridge;

	if ((r.fd = client_net_setup(bridge_name)) == -1)
		goto fail_bridge;

	if (router_net_setup(bridge_name, router_vm_name, router_mac,
			     &router_vm_net_device) == -1)
		goto fail_bridge;

	// Set up a process that will listen for this process dying,
	// and remove the interface from the netvm, and delete the
	// bridge.
	exit_listener_setup(router_vm_name, router_vm_net_device);

	goto out;

fail_bridge:
	bridge_delete(bridge_name);
	close(r.fd);
	r.fd = -1;
out:
	ch_device_free(router_vm_net_device);
	return r;
}
