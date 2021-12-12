#!/bin/sh
#
# SPDX-FileCopyrightText: 2021 Alyssa Ross <hi@alyssa.is>
# SPDX-License-Identifier: EUPL-1.2
#
# usage: qemu-pty.sh socket-path chardev-name

nc -U "$1" <<IN | jq -rn --arg name "$2" 'first(inputs | .return | arrays)[] |
	select(.label == $name) | .filename | ltrimstr("pty:")'
{"execute":"qmp_capabilities"}
{"execute":"query-chardev"}
IN
