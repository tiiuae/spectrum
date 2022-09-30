# SPDX-License-Identifier: EUPL-1.2+
# SPDX-FileCopyrightText: 2021-2022 Alyssa Ross <hi@alyssa.is>

# qemu-kvm is non-standard, but is present in at least Fedora and
# Nixpkgs.  If you don't have qemu-kvm, you'll need to set e.g.
# QEMU_KVM = qemu-system-x86_64 -enable-kvm.
QEMU_KVM = qemu-kvm

CPIO = cpio
CPIOFLAGS = --reproducible -R +0:+0 -H newc
SCRIPTS = ../../scripts
VERITYSETUP = veritysetup

build/initramfs: $(MICROCODE) build/local.cpio $(PACKAGES_CPIO)
	cat $(MICROCODE) > $@
	cat build/local.cpio $(PACKAGES_CPIO) | gzip -9n >> $@

# etc/init isn't included in ETC_FILES, because it gets installed to
# the root.
ETC_FILES = etc/getuuids etc/probe etc/fstab etc/mdev.conf
MOUNTPOINTS = dev mnt/root proc sys tmp

build/local.cpio: $(ETC_FILES) etc/init build/mountpoints
	printf "%s\n" $(ETC_FILES) | \
	    awk '{while (length) { print; sub("/?[^/]*$$", "") }}' | \
	    sort -u | \
	    $(CPIO) -o $(CPIOFLAGS) > $@
	cd etc && echo init | $(CPIO) -o $(CPIOFLAGS) -AF ../$@
	cd build/mountpoints && printf "%s\n" $(MOUNTPOINTS) | \
	    awk '{while (length) { print; sub("/?[^/]*$$", "") }}' | \
	    sort -u | \
	    $(CPIO) -o $(CPIOFLAGS) -AF ../../$@

build/mountpoints:
	rm -rf build/mountpoints
	mkdir -p build/mountpoints
	cd build/mountpoints && mkdir -p $(MOUNTPOINTS)
	find build/mountpoints -mindepth 1 -exec touch -d @0 {} ';'

# veritysetup format produces two files, but Make only (portably)
# supports one output per rule, so we combine the two outputs then
# define two more rules to separate them again.
build/rootfs.verity: $(ROOT_FS)
	mkdir -p build
	$(VERITYSETUP) format $(ROOT_FS) build/rootfs.verity.superblock.tmp \
	    | awk -F ':[[:blank:]]*' '$$1 == "Root hash" {print $$2; exit}' \
	    > build/rootfs.verity.roothash.tmp
	cat build/rootfs.verity.roothash.tmp build/rootfs.verity.superblock.tmp \
	    > $@
	rm build/rootfs.verity.roothash.tmp build/rootfs.verity.superblock.tmp
build/rootfs.verity.roothash: build/rootfs.verity
	head -n 1 build/rootfs.verity > $@
build/rootfs.verity.superblock: build/rootfs.verity
	tail -n +2 build/rootfs.verity > $@

build/live.img: $(SCRIPTS)/format-uuid.sh $(SCRIPTS)/make-gpt.sh build/rootfs.verity.superblock build/rootfs.verity.roothash $(ROOT_FS) $(EXT_FS)
	$(SCRIPTS)/make-gpt.sh $@.tmp \
	    build/rootfs.verity.superblock:2c7357ed-ebd2-46d9-aec1-23d437ec2bf5:$$($(SCRIPTS)/format-uuid.sh "$$(dd if=build/rootfs.verity.roothash bs=32 skip=1 count=1 status=none)") \
	    $(ROOT_FS):4f68bce3-e8cd-4db1-96e7-fbcaf984b709:$$($(SCRIPTS)/format-uuid.sh "$$(head -c 32 build/rootfs.verity.roothash)")
	mv $@.tmp $@

clean:
	rm -rf build
.PHONY: clean
extfs: $(EXT_FS)

run: build/initramfs build/rootfs.verity.roothash build/live.img
	$(QEMU_KVM) -m 4G \
	    -kernel $(KERNEL) \
	    -initrd build/initramfs \
	    -append "ro console=ttyS0 ext=vda roothash=$$(< build/rootfs.verity.roothash)" \
	    -cpu host \
	    -display gtk,gl=on \
	    -device virtio-vga-gl \
	    -device qemu-xhci \
	    -device usb-storage,drive=drive1,removable=true \
	    -drive file=build/live.img,id=drive1,format=raw,if=none,readonly=true \
	    -drive file=$(EXT_FS),format=raw,if=virtio,readonly=true
.PHONY: run
