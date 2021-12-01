# SPDX-License-Identifier: EUPL-1.2
# SPDX-FileCopyrightText: 2021 Alyssa Ross <hi@alyssa.is>

build/initramfs: build/local.cpio $(PACKAGES_CPIO)
	cat build/local.cpio $(PACKAGES_CPIO) | gzip -9n > $@

build/local.cpio: etc/init etc/mdev.conf
	rm -rf build/root

	mkdir -p build/root/{dev,etc,mnt,proc,sys,tmp}
	install etc/init build/root/init
	cp etc/mdev.conf build/root/etc/mdev.conf

	find build/root -print0 | xargs -0r touch -h -d '@1'
	(cd build/root; find . -print0 | sort -z | cpio -o -H newc -R +0:+0 --reproducible --null) > $@

clean:
	rm -rf build
.PHONY: clean
