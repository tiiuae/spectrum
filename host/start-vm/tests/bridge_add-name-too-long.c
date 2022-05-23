// SPDX-License-Identifier: EUPL-1.2+
// SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>

#include "../net-util.h"

#include <assert.h>
#include <errno.h>
#include <net/if.h>
#include <string.h>

int main(void)
{
	char name[IFNAMSIZ];
	memset(name, 'a', sizeof name);
	assert(bridge_add(name) == -1);
	assert(errno == ENAMETOOLONG);
}
