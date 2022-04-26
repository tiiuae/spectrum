#!/bin/sh -eu
# SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>
# SPDX-License-Identifier: EUPL-1.2

cd "$(dirname "$0")/../.."

PATTERN='\b[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}\b'
UUID_REFERENCE_PATH=Documentation/uuid-reference.adoc

git ls-files -coz --exclude-standard |
    grep -Fxvz "$UUID_REFERENCE_PATH" |
    xargs -0 git grep -Ehio --no-index --no-line-number "$PATTERN" -- |
    sort -u |
    comm -23 - <(grep -Eio "$PATTERN" "$UUID_REFERENCE_PATH" | sort -u)
