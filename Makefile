# SPDX-License-Identifier: EUPL-1.2
# SPDX-FileCopyrightText: 2021 Alyssa Ross <hi@alyssa.is>

CPIO = cpio
CPIOFLAGS = --reproducible -R +0:+0 -H newc

build/initramfs: build/local.cpio $(PACKAGES_CPIO)
	cat build/local.cpio $(PACKAGES_CPIO) | gzip -9n > $@

# etc/init isn't included in ETC_FILES, because it gets installed to
# the root.
ETC_FILES = etc/checkesp etc/fstab etc/mdev.conf
MOUNTPOINTS = dev mnt proc sys tmp

build/local.cpio: $(ETC_FILES) etc/init build/mountpoints
	printf "%s\n" $(ETC_FILES) | \
	    awk '{while (length) { print; sub("/?[^/]*$$", "") }}' | \
	    sort -u | \
	    $(CPIO) -o $(CPIOFLAGS) > $@
	cd etc && echo init | $(CPIO) -o $(CPIOFLAGS) -AF ../$@
	cd build/mountpoints && \
	    printf "%s\n" $(MOUNTPOINTS) | $(CPIO) -o $(CPIOFLAGS) -AF ../../$@

build/mountpoints:
	rm -rf build/mountpoints
	mkdir -p build/mountpoints
	cd build/mountpoints && mkdir -p $(MOUNTPOINTS)
	find build/mountpoints -mindepth 1 -exec touch -d @0 {} ';'

clean:
	rm -rf build
.PHONY: clean
