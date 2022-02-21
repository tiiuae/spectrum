// SPDX-License-Identifier: EUPL-1.2
// SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>

#include "../net-util.h"

#include <assert.h>
#include <errno.h>
#include <net/if.h>
#include <stdio.h>
#include <stdlib.h>
#include <sched.h>
#include <string.h>

#include <sys/ioctl.h>

#include <linux/if_tun.h>

int main(void)
{
	char newname[IFNAMSIZ], name[IFNAMSIZ] = "tap%d";
	struct ifreq ifr;
	int r, fd;

	unshare(CLONE_NEWUSER|CLONE_NEWNET);

	r = snprintf(newname, sizeof newname, "_tap%d", rand());
	assert(r > 0 && (size_t)r < sizeof newname);
	if ((fd = tap_open(name, 0)) == -1)
		return errno == EPERM ? 77 : 1;
	assert(!if_rename(name, newname));
	assert(!ioctl(fd, TUNGETIFF, &ifr));
	assert(!strcmp(ifr.ifr_name, newname));
}
