#!/bin/sh -eu
#
# SPDX-FileCopyrightText: 2021-2022 Alyssa Ross <hi@alyssa.is>
# SPDX-FileCopyrightText: 2022 Unikie
# SPDX-License-Identifier: EUPL-1.2+

substr () {
    str=$1
    beg=$2
    end=$3
    echo $(echo $str | cut -c $beg-$end)
}

u1=$(substr $1 1 8)
u2=$(substr $1 9 12)
u3=$(substr $1 13 16)
u4=$(substr $1 17 20)
u5=$(substr $1 21 32)
printf "%s\n" "$u1-$u2-$u3-$u4-$u5"
