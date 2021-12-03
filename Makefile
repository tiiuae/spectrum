# SPDX-License-Identifier: EUPL-1.2
# SPDX-FileCopyrightText: 2021 Alyssa Ross <hi@alyssa.is>

CPIO = cpio
CPIOFLAGS = --reproducible -R +0:+0 -H newc

build/initramfs: build/local.cpio $(PACKAGES_CPIO)
	cat build/local.cpio $(PACKAGES_CPIO) | gzip -9n > $@

MOUNTPOINTS = dev mnt proc sys tmp

build/local.cpio: etc/checkesp etc/init etc/mdev.conf build/mountpoints
	printf "%s\n" etc etc/checkesp etc/mdev.conf | \
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
