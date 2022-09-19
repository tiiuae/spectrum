#!/bin/sh -eu
#
# SPDX-FileCopyrightText: 2021-2022 Alyssa Ross <hi@alyssa.is>
# SPDX-License-Identifier: EUPL-1.2+
#
# usage: make-gpt.sh GPT_PATH PATH:PARTTYPE[:PARTUUID[:PARTLABEL]]...

ONE_MiB=1048576
TWO_MiB=2097152

# Prints the number of 1MiB blocks required to store the file named
# $1.  We use 1MiB blocks because that's what sfdisk uses for
# alignment.  It would be possible to get a slightly smaller image
# using actual normal-sized 512-byte blocks, but it's probably not
# worth it to configure sfdisk to do that.
sizeMiB() {
	wc -c "$1" | awk -v ONE_MiB=$ONE_MiB \
		'{printf "%d\n", ($1 + ONE_MiB - 1) / ONE_MiB}'
}

# Copies from path $3 into partition number $2 in partition table $1.
fillPartition() {
	sfdisk -J "$1" | jq -r --argjson index "$2" \
		'.partitiontable.partitions[$index] | "\(.start) \(.size)"' |
		(read start size;
		 dd if="$3" of="$1" seek="$start" count="$size" conv=notrunc)
}

# Prints the partition path from a PATH:PARTTYPE[:PARTUUID[:PARTLABEL]] string.
partitionPath() {
	awk -F: '{print $1}' <<EOF
$1
EOF
}

scriptsDir="$(dirname "$0")"

out="$1"
shift

nl=$'\n'
table="label: gpt"

# Keep 1MiB free at the start, and 1MiB free at the end.
gptBytes=$TWO_MiB
for partition; do
	sizeMiB="$(sizeMiB "$(partitionPath "$partition")")"
	table="$table${nl}size=${sizeMiB}MiB,$(awk -f "$scriptsDir/sfdisk-field.awk" -v partition="$partition")"
	gptBytes="$(expr "$gptBytes" + "$sizeMiB" \* $ONE_MiB)"
done

rm -f "$out"
truncate -s "$gptBytes" "$out"
sfdisk "$out" <<EOF
$table
EOF

n=0
for partition; do
	fillPartition "$out" "$n" "$(partitionPath "$partition")"
	n="$(expr "$n" + 1)"
done
