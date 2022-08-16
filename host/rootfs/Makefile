# SPDX-License-Identifier: EUPL-1.2+
# SPDX-FileCopyrightText: 2021-2022 Alyssa Ross <hi@alyssa.is>

# qemu-kvm is non-standard, but is present in at least Fedora and
# Nixpkgs.  If you don't have qemu-kvm, you'll need to set e.g.
# QEMU_KVM = qemu-system-x86_64 -enable-kvm.
QEMU_KVM = qemu-kvm

# tar2ext4 will leave half a filesystem behind if it's interrupted
# half way through.
build/rootfs.ext4: build/rootfs.tar $(EXT_FS)
	tar2ext4 -i build/rootfs.tar -o $@.tmp
	mv $@.tmp $@
	cp -f $(EXT_FS) build/extfs.ext4

FILES = \
	etc/fonts/fonts.conf \
	etc/fstab \
	etc/group \
	etc/init \
	etc/login \
	etc/mdev.conf \
	etc/mdev/block/add \
	etc/mdev/listen \
	etc/mdev/net/add \
	etc/mdev/wait \
	etc/parse-devname \
	etc/passwd \
	etc/s6-linux-init/run-image/service/getty-tty1/run \
	etc/s6-linux-init/run-image/service/getty-tty2/run \
	etc/s6-linux-init/run-image/service/getty-tty3/run \
	etc/s6-linux-init/run-image/service/getty-tty4/run \
	etc/s6-linux-init/run-image/service/getty-ttyS0/run \
	etc/s6-linux-init/scripts/rc.init \
	etc/xdg/weston/autolaunch \
	etc/xdg/weston/weston.ini \
	usr/bin/lsvm \
	usr/bin/vm-console \
	usr/bin/vm-start \
	usr/bin/vm-stop
DIRS = dev etc/s6-linux-init/env ext run proc sys

# These are separate because they need to be included, but putting
# them as make dependencies would confuse make.
LINKS = bin sbin

BUILD_FILES = build/etc/mdev/modalias.sh build/etc/s6-rc

build/empty:
	mkdir -p $@

build/rootfs.tar: build/empty $(PACKAGES_TAR) $(FILES) $(BUILD_FILES)
	cp --no-preserve=mode -f $(PACKAGES_TAR) $@
	tar $(TARFLAGS) --append -f $@ $(FILES) $(LINKS)
	echo $(BUILD_FILES) | cut -d/ -f2 | \
	    tar $(TARFLAGS) --append -f $@ -C build -T -
	for m in $(DIRS); do \
	    tar $(TARFLAGS) --append -hf $@ --xform="s,.*,$$m," build/empty ; \
	done

build/etc/mdev/modules.map: scripts/modprobe/gen_modules.map.awk
	mkdir -p $$(dirname $@)
	awk -f scripts/modprobe/gen_modules.map.awk \
		$(MODULES_ORDER) > $@ || rm -f $@

build/etc/mdev/modalias.sh: scripts/modprobe/gen_modalias.sh.awk build/etc/mdev/modules.map
	mkdir -p $$(dirname $@)
	awk -v modmap=build/etc/mdev/modules.map \
		-f scripts/modprobe/gen_modalias.sh.awk \
		$(MODULES_ALIAS) > $@ || rm -f $@
	chmod +x $@

S6_RC_FILES = \
	etc/s6-rc/card0/type \
	etc/s6-rc/card0/up \
	etc/s6-rc/core/type \
	etc/s6-rc/core/up \
	etc/s6-rc/ext-rc-init/dependencies \
	etc/s6-rc/ext-rc-init/type \
	etc/s6-rc/ext-rc-init/up \
	etc/s6-rc/ext-rc/contents \
	etc/s6-rc/ext-rc/type \
	etc/s6-rc/ext/type \
	etc/s6-rc/ext/up \
	etc/s6-rc/mdevd-coldplug/dependencies \
	etc/s6-rc/mdevd-coldplug/type \
	etc/s6-rc/mdevd-coldplug/up \
	etc/s6-rc/mdevd/notification-fd \
	etc/s6-rc/mdevd/run \
	etc/s6-rc/mdevd/type \
	etc/s6-rc/ok-all/contents \
	etc/s6-rc/ok-all/type \
	etc/s6-rc/static-nodes/type \
	etc/s6-rc/static-nodes/up \
	etc/s6-rc/weston/dependencies \
	etc/s6-rc/weston/notification-fd \
	etc/s6-rc/weston/type \
	etc/s6-rc/weston/run

# s6-rc-compile's input is a directory, but that doesn't play nice
# with Make, because it won't know to update if some file in the
# directory is changed, or a file is created or removed in a
# subdirectory.  Using the whole source directory could also end up
# including files that aren't intended to be part of the input, like
# temporary editor files or .license files.  So for all these reasons,
# only explicitly listed files are made available to s6-rc-compile.
build/etc/s6-rc: $(S6_RC_FILES)
	mkdir -p $$(dirname $@)
	rm -rf $@

	dir=$$(mktemp -d) && \
	    tar -c $(S6_RC_FILES) | tar -C $$dir -x --strip-components 2 && \
	    s6-rc-compile $@ $$dir; \
	    exit=$$?; rm -r $$dir; exit $$exit

clean:
	rm -rf build
.PHONY: clean

run: build/rootfs.ext4
	$(QEMU_KVM) -cpu host -m 2G \
	    -machine q35,kernel=$(KERNEL),kernel-irqchip=split \
	    -display gtk,gl=on \
	    -qmp unix:vmm.sock,server,nowait \
	    -monitor vc \
	    -parallel none \
	    -drive file=build/rootfs.ext4,if=virtio,format=raw,readonly=on \
	    -drive file=$(EXT_FS),if=virtio,format=raw,readonly=on \
	    -append "console=ttyS0 root=/dev/vda ext=/dev/vdb intel_iommu=on" \
	    -device intel-iommu,intremap=on \
	    -device virtio-vga-gl \
	    -device vhost-vsock-pci,guest-cid=3
.PHONY: run
