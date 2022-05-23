// SPDX-License-Identifier: EUPL-1.2+
// SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>

#include "../net-util.h"

#include <assert.h>
#include <errno.h>

int main(void)
{
	assert(bridge_add("br%d") == -1);
	assert(errno == EINVAL);
}
