// SPDX-License-Identifier: EUPL-1.2+
// SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>

#include "../net-util.h"

#include <assert.h>
#include <errno.h>
#include <sched.h>
#include <stdio.h>
#include <stdlib.h>

#include <sys/mount.h>
#include <sys/stat.h>

int main(void)
{
	char bridge_name[IFNAMSIZ], tap_name[IFNAMSIZ] = "tap%d";
	char brif_path[32 + IFNAMSIZ * 2];
	int r, tap;
	struct stat statbuf;

	if (!unshare(CLONE_NEWUSER|CLONE_NEWNET|CLONE_NEWNS)) {
		if (mount("sysfs", "/sys", "sysfs", 0, NULL) == -1)
			return errno == ENOENT ? 77 : 1;
	}

	tap = tap_open(tap_name, 0);
	if (tap == -1)
		return errno == EPERM || errno == ENOENT ? 77 : 1;

	r = snprintf(bridge_name, sizeof bridge_name, "br%d", rand());
	assert(r > 0 && (size_t)r < sizeof bridge_name);
	assert(bridge_add(bridge_name) != -1);

	assert(bridge_add_if(bridge_name, tap_name) != -1);
	assert(bridge_remove_if(bridge_name, tap_name) != -1);

	r = snprintf(brif_path, sizeof brif_path,
		     "/sys/devices/virtual/net/%s/brif/%s",
		     bridge_name, tap_name);
	assert(r > 0 && (size_t)r < sizeof brif_path);

	assert(lstat(brif_path, &statbuf) == -1);
	assert(errno == ENOENT);
}
