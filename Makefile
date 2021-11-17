# SPDX-License-Identifier: EUPL-1.2
# SPDX-FileCopyrightText: 2021 Alyssa Ross <hi@alyssa.is>

# qemu-kvm is non-standard, but is present in at least Fedora and
# Nixpkgs.  If you don't have qemu-kvm, you'll need to set e.g.
# QEMU_KVM = qemu-system-x86_64 -enable-kvm.
QEMU_KVM = qemu-kvm
SCREEN = screen

# tar2ext4 will leave half a filesystem behind if it's interrupted
# half way through.
build/rootfs.ext4: build/rootfs.tar
	tar2ext4 -i build/rootfs.tar -o $@.tmp
	mv $@.tmp $@

build/test.img: scripts/make-gpt.sh build/rootfs.ext4 $(EXT_FS)
	scripts/make-gpt.sh $@.tmp \
		build/rootfs.ext4:4f68bce3-e8cd-4db1-96e7-fbcaf984b709 \
		$(EXT_FS):9293e1ff-cee4-4658-88be-898ec863944f
	mv $@.tmp $@

FILES = \
	etc/fonts/fonts.conf \
	etc/fstab \
	etc/group \
	etc/init \
	etc/login/kind/tty \
	etc/login/kind/ttyS \
	etc/login/share/prelude \
	etc/login/share/sh \
	etc/mdev.conf \
	etc/parse-devname \
	etc/passwd \
	etc/service/getty-tty1/run \
	etc/service/getty-tty2/run \
	etc/service/getty-tty3/run \
	etc/service/getty-tty4/run \
	etc/service/getty-ttyS0/run \
	etc/xdg/weston/autolaunch \
	etc/xdg/weston/weston.ini

# These are separate because they need to be included, but putting
# them as make dependencies would confuse make.
LINKS = bin sbin

BUILD_FILES = build/etc/s6-rc
MOUNTPOINTS = dev ext run proc sys

build/rootfs.tar: $(PACKAGES_TAR) $(FILES) $(BUILD_FILES)
	cp --no-preserve=mode -f $(PACKAGES_TAR) $@
	tar $(TARFLAGS) --append -f $@ $(FILES) $(LINKS)
	echo $(BUILD_FILES) | cut -d/ -f2 | \
	    tar $(TARFLAGS) --append -f $@ -C build -T -
	for m in $(MOUNTPOINTS); do \
	    tar $(TARFLAGS) --append -hf $@ --xform="s,.*,$$m," /var/empty ; \
	done
	tar $(TARFLAGS) --append -hf $@ --xform='s,.*,etc/service,' /var/empty

S6_RC_FILES = \
	etc/s6-rc/ext-rc/dependencies \
	etc/s6-rc/ext-rc/type \
	etc/s6-rc/ext-rc/up \
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

run: build/test.img
	$(QEMU_KVM) -cpu host -m 6G \
	    -machine q35,kernel=$(KERNEL),kernel-irqchip=split \
	    -display gtk,gl=on \
	    -qmp unix:vmm.sock,server,nowait \
	    -drive file=build/test.img,if=virtio,format=raw,readonly=on \
	    -append "console=ttyS0 root=/dev/vda1 intel_iommu=on" \
	    -device intel-iommu,intremap=on \
	    -device virtio-vga-gl
.PHONY: run

console:
	@$(SCREEN) "$$(scripts/qemu-pty.sh vmm.sock virtiocon0)"
.PHONY: console
