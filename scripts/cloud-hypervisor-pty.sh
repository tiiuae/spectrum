#!/bin/sh
#
# SPDX-FileCopyrightText: 2021 Alyssa Ross <hi@alyssa.is>
# SPDX-License-Identifier: EUPL-1.2
#
# usage: cloud-hypervisor-pty.sh socket-path [ignored]

curl --unix-socket "$1" http://localhost/api/v1/vm.info |
    jq -r .config.console.file
