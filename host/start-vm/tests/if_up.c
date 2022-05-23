// SPDX-License-Identifier: EUPL-1.2+
// SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>

#include "../net-util.h"

#include <assert.h>
#include <errno.h>
#include <sched.h>
#include <string.h>

#include <sys/ioctl.h>

#include <linux/if_tun.h>

int main(void)
{
	char name[IFNAMSIZ] = "tap%d";
	struct ifreq ifr;
	int fd;

	unshare(CLONE_NEWUSER|CLONE_NEWNET);

	if (tap_open(name, 0) == -1 && (errno == EPERM || errno == ENOENT))
		return 77;
	assert(!if_up(name));

	assert((fd = socket(AF_UNIX, SOCK_STREAM, 0)) != -1);
	strncpy(ifr.ifr_name, name, IFNAMSIZ);
	assert(!ioctl(fd, SIOCGIFFLAGS, &ifr));
	assert(ifr.ifr_flags & IFF_UP);
}
