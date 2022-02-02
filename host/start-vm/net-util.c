// SPDX-License-Identifier: EUPL-1.2
// SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>

#include <fcntl.h>
#include <net/if.h>
#include <string.h>
#include <unistd.h>

#include <sys/ioctl.h>

#include <linux/if_tun.h>
#include <linux/sockios.h>

// ifr_name doesn't have to be null terminated.
#pragma GCC diagnostic ignored "-Wstringop-truncation"

int if_up(const char *name)
{
	struct ifreq req;
	int fd, r = -1;

	if ((fd = socket(AF_UNIX, SOCK_STREAM|SOCK_CLOEXEC, 0)) == -1)
		return -1;

	strncpy(req.ifr_name, name, IFNAMSIZ);
	if (ioctl(fd, SIOCGIFFLAGS, &req) == -1)
		goto out;
	req.ifr_flags |= IFF_UP;
	r = ioctl(fd, SIOCSIFFLAGS, &req);
out:
	close(fd);
	return r;
}

int bridge_add(const char *name)
{
	int fd, r;
	if ((fd = socket(AF_UNIX, SOCK_STREAM|SOCK_CLOEXEC, 0)) == -1)
		return -1;
	r = ioctl(fd, SIOCBRADDBR, name);
	close(fd);
	return r;
}

int bridge_add_if(const char *brname, const char *ifname)
{
	struct ifreq ifr;
	int fd, r;

	strncpy(ifr.ifr_name, brname, IFNAMSIZ);
	if (!(ifr.ifr_ifindex = if_nametoindex(ifname)))
		return -1;

	if ((fd = socket(AF_UNIX, SOCK_STREAM|SOCK_CLOEXEC, 0)) == -1)
		return -1;

	r = ioctl(fd, SIOCBRADDIF, &ifr);
	close(fd);
	return r;
}

int bridge_delete(const char *name)
{
	int fd, r;

	if ((fd = socket(AF_UNIX, SOCK_STREAM|SOCK_CLOEXEC, 0)) == -1)
		return -1;

	r = ioctl(fd, SIOCBRDELBR, name);
	close(fd);
	return r;
}

int tap_open(const char *name, int flags)
{
	struct ifreq ifr;
	int fd;

	if ((fd = open("/dev/net/tun", O_RDWR)) == -1)
		return -1;

	strncpy(ifr.ifr_name, name, IFNAMSIZ);
	ifr.ifr_flags = IFF_TAP|flags;
	if (!ioctl(fd, TUNSETIFF, &ifr))
		return fd;

	close(fd);
	return -1;
}
