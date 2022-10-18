# SPDX-License-Identifier: EUPL-1.2+
# SPDX-FileCopyrightText: 2021-2022 Alyssa Ross <hi@alyssa.is>

# qemu-kvm is non-standard, but is present in at least Fedora and
# Nixpkgs.  If you don't have qemu-kvm, you'll need to set e.g.
# QEMU_KVM = qemu-system-x86_64 -enable-kvm.
QEMU_KVM = qemu-kvm

SCRIPTS = ../../scripts
VERITYSETUP = veritysetup

# tar2ext4 will leave half a filesystem behind if it's interrupted
# half way through.
build/rootfs.ext4: build/rootfs.tar
	tar2ext4 -i build/rootfs.tar -o $@.tmp
	dd if=/dev/zero of=$@.tmp bs=1MiB count=500 conv=notrunc oflag=append
	resize2fs $@.tmp
	tune2fs -O ^read-only $@.tmp
	mv $@.tmp $@

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
	etc/template/gpu/data/check \
	etc/template/gpu/notification-fd \
	etc/template/gpu/run \
	etc/template/gpu/type \
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

# veritysetup format produces two files, but Make only (portably)
# supports one output per rule, so we combine the two outputs then
# define two more rules to separate them again.
build/rootfs.verity: build/rootfs.ext4
	$(VERITYSETUP) format build/rootfs.ext4 build/rootfs.verity.superblock.tmp \
	    | awk -F ':[[:blank:]]*' '$$1 == "Root hash" {print $$2; exit}' \
	    > build/rootfs.verity.roothash.tmp
	cat build/rootfs.verity.roothash.tmp build/rootfs.verity.superblock.tmp \
	    > $@
	rm build/rootfs.verity.roothash.tmp build/rootfs.verity.superblock.tmp
build/rootfs.verity.roothash: build/rootfs.verity
	head -n 1 build/rootfs.verity > $@
build/rootfs.verity.superblock: build/rootfs.verity
	tail -n +2 build/rootfs.verity > $@

build/live.img: $(SCRIPTS)/format-uuid.sh $(SCRIPTS)/make-gpt.sh build/rootfs.verity.superblock build/rootfs.verity.roothash build/rootfs.ext4
	$(SCRIPTS)/make-gpt.sh $@.tmp \
	    build/rootfs.verity.superblock:2c7357ed-ebd2-46d9-aec1-23d437ec2bf5:$$($(SCRIPTS)/format-uuid.sh "$$(dd if=build/rootfs.verity.roothash bs=32 skip=1 count=1 status=none)") \
	    build/rootfs.ext4:4f68bce3-e8cd-4db1-96e7-fbcaf984b709:$$($(SCRIPTS)/format-uuid.sh "$$(head -c 32 build/rootfs.verity.roothash)")
	mv $@.tmp $@

run: build/live.img $(EXT_FS) build/rootfs.verity.roothash
	$(QEMU_KVM) -cpu host -m 2G \
	    -machine q35,kernel=$(KERNEL),kernel-irqchip=split,initrd=$(INITRAMFS) \
	    -display gtk,gl=on \
	    -qmp unix:vmm.sock,server,nowait \
	    -monitor vc \
	    -parallel none \
	    -drive file=build/live.img,if=virtio,format=raw,readonly=off \
	    -drive file=$(EXT_FS),if=virtio,format=raw,readonly=on \
	    -append "console=ttyS0 roothash=$$(< build/rootfs.verity.roothash) ext=/dev/vdb intel_iommu=on" \
	    -device intel-iommu,intremap=on \
	    -device virtio-vga-gl \
	    -device vhost-vsock-pci,guest-cid=3
.PHONY: run
