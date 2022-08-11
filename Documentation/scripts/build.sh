#!/bin/sh -e
# SPDX-FileCopyrightText: 2022 Unikie
# SPDX-License-Identifier: EUPL-1.2+

cd "$(dirname "$0")/.."

if [ ! -w . -a ! -w .jekyll-cache ]; then
	JEKYLLFLAGS=--disable-disk-cache
fi

find . '(' '!' -path ./_site -o -prune ')' \
	-a -name '*.drawio' \
	-exec drawio -xf svg '{}' ';'
jekyll build $JEKYLLFLAGS -b /doc -d "${1:-_site}"
