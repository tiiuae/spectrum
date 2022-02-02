// SPDX-License-Identifier: EUPL-1.2
// SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>

#include "net-util.h"

#include <errno.h>
#include <inttypes.h>
#include <net/if.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/uio.h>
#include <sys/un.h>

#include <linux/if_tun.h>

#define MAC_STR_LEN 17

int format_mac(char s[static MAC_STR_LEN + 1], const uint8_t mac[6])
{
	return snprintf(s, MAC_STR_LEN + 1,
			"%.2hhX:%.2hhX:%.2hhX:%.2hhX:%.2hhX:%.2hhX",
			mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
}

static int dial_un(const char *sun_path)
{
	struct sockaddr_un addr = { 0 };
	int fd = socket(AF_UNIX, SOCK_STREAM|SOCK_CLOEXEC, 0);
	if (fd == -1)
		return -1;

	addr.sun_family = AF_UNIX;
	strncpy(addr.sun_path, sun_path, sizeof addr.sun_path);

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Warray-bounds"
	// Safe because if the last byte of addr.sun_path is non-zero,
	// sun_path must be at least one byte longer.
	if (addr.sun_path[sizeof addr.sun_path - 1] &&
	    sun_path[sizeof addr.sun_path]) {
#pragma GCC diagnostic pop
		errno = E2BIG;
		goto fail;
	}

	if (connect(fd, (struct sockaddr *)&addr, sizeof addr) == -1)
		goto fail;

	return fd;
fail:
	close(fd);
	return -1;
}

static int sendv_with_fd(int sock, const struct iovec iov[], size_t iovlen,
			 int fd, int flags)
{
	struct msghdr msg = { 0 };
	struct cmsghdr *cmsg;
	union {
		char buf[CMSG_SPACE(sizeof fd)];
		struct cmsghdr _align;
	} u;

	msg.msg_iov = (struct iovec *)iov;
	msg.msg_iovlen = iovlen;
	msg.msg_control = u.buf;
	msg.msg_controllen = sizeof u.buf;

	cmsg = CMSG_FIRSTHDR(&msg);
	cmsg->cmsg_level = SOL_SOCKET;
	cmsg->cmsg_type = SCM_RIGHTS;
	cmsg->cmsg_len = CMSG_LEN(sizeof fd);
	memcpy(CMSG_DATA(cmsg), &fd, sizeof fd);

	return sendmsg(sock, &msg, flags);
}

static int ch_add_net(const char *vm_name, int tap, const uint8_t mac[6])
{
	char mac_s[MAC_STR_LEN + 1];
	char path[sizeof ((struct sockaddr_un *)0)->sun_path] = { 0 };
	int sock = -1;
	uint16_t status = 0;
	FILE *f = NULL;
	static const char buf1[] =
		"PUT /api/v1/vm.add-net HTTP/1.1\r\n"
		"Host: localhost\r\n"
		"Content-Type: application/json\r\n"
		"Content-Length: 27\r\n"
		"\r\n"
		"{\"mac\":\"";
	static const char buf2[] = "\"}";

	if (format_mac(mac_s, mac) == -1)
		return -1;

	struct iovec iov[] = {
		{ .iov_base = (void *)buf1, .iov_len = sizeof buf1 - 1 },
		{ .iov_base = (void *)mac_s, .iov_len = MAC_STR_LEN },
		{ .iov_base = (void *)buf2, .iov_len = sizeof buf2 - 1 },
	};

	if (snprintf(path, sizeof path,
		     "/run/service/ext-%s-vmm/env/cloud-hypervisor.sock",
		     vm_name) >= (ssize_t)sizeof path) {
		errno = E2BIG;
		return -1;
	}

	if ((sock = dial_un(path)) == -1)
		goto out;

	if (sendv_with_fd(sock, iov, sizeof iov / sizeof *iov, tap, 0) == -1)
		goto out;

	f = fdopen(sock, "r");
	sock = -1; // now owned by f
	if (!f)
		goto out;

	if (fscanf(f, "%*s %" SCNu16, &status) != 1)
		status = 0;

	if (status < 200 || status >= 300) {
		fputs("Failed cloud-hypervisor API request:\n", stderr);
		fflush(stderr);
		writev(STDERR_FILENO, iov, sizeof iov / sizeof *iov);
		fputs("\n", stderr);
	}
out:
	close(sock);
	if (f)
		fclose(f);
	return (200 <= status && status < 300) - 1;
}

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
			    const uint8_t mac[6])
{
	int r, fd = setup_tap(bridge_name, "router");
	if (fd == -1)
		return -1;

	r = ch_add_net(router_vm_name, fd, mac);
	close(fd);
	return r;
}

struct net_config {
	int fd;
	char mac[6];
};

struct net_config net_setup(const char *router_vm_name)
{
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

	if (router_net_setup(bridge_name, router_vm_name, router_mac) == -1)
		goto fail_bridge;

	goto out;

fail_bridge:
	bridge_delete(bridge_name);
	close(r.fd);
	r.fd = -1;
out:
	return r;
}
