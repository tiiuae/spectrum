#!/usr/bin/awk -f
#
# SPDX-License-Identifier: EUPL-1.2+
# SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>

BEGIN {
	# Field #1 is the partition path, which make-gpt.sh will turn into
	# the size field.  Since it's handled elsewhere, we skip that
	# first field.
	skip=1

	split("type uuid name", keys)
	split(partition, fields, ":")

	for (n in fields) {
		if (n <= skip)
			continue
		printf "%s=%s,", keys[n - skip], fields[n]
	}
}
