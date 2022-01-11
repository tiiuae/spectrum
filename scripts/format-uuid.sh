#!/bin/sh -eu
#
# SPDX-FileCopyrightText: 2021-2022 Alyssa Ross <hi@alyssa.is>
# SPDX-License-Identifier: EUPL-1.2

printf "%s\n" "${1:0:8}-${1:8:4}-${1:12:4}-${1:16:4}-${1:20}"
