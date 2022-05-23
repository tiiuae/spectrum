// SPDX-License-Identifier: EUPL-1.2+
// SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>

#include "../net-util.h"

#include <assert.h>
#include <errno.h>
#include <sched.h>

int main(void)
{
	char name[IFNAMSIZ] = "tap%d";

	unshare(CLONE_NEWUSER|CLONE_NEWNET);

	if (tap_open(name, 0) == -1)
		return errno == EPERM || errno == ENOENT ? 77 : 1;
	assert(if_rename(name, "tap%d") == -1);
	assert(errno == EINVAL);
}
