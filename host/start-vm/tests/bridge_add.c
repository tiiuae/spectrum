// SPDX-License-Identifier: EUPL-1.2+
// SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>

#include "../net-util.h"

#include <assert.h>
#include <errno.h>
#include <sched.h>
#include <stdio.h>
#include <stdlib.h>

int main(void)
{
	char name[IFNAMSIZ];
	int r;

	unshare(CLONE_NEWUSER|CLONE_NEWNET);

	r = snprintf(name, sizeof name, "br%d", rand());
	assert(r > 0 && (size_t)r < sizeof name);
	if (bridge_add(name) == -1)
		return errno == EPERM ? 77 : 1;
	assert(if_nametoindex(name));
}
