# SPDX-License-Identifier: EUPL-1.2
# SPDX-FileCopyrightText: 2021 Alyssa Ross <hi@alyssa.is>

# qemu-kvm is non-standard, but is present in at least Fedora and
# Nixpkgs.  If you don't have qemu-kvm, you'll need to set e.g.
# QEMU_KVM = qemu-system-x86_64 -enable-kvm.
QEMU_KVM = qemu-kvm

TARFLAGS = -v --show-transformed-names

HOST_S6_RC_FILES = \
	host/netvm/run \
	host/netvm/type

HOST_S6_RC_BUILD_FILES = \
	build/host/netvm/data/rootfs.ext4 \
	build/host/netvm/data/vmlinux

# s6-rc-compile's input is a directory, but that doesn't play nice
# with Make, because it won't know to update if some file in the
# directory is changed, or a file is created or removed in a
# subdirectory.  Using the whole source directory could also end up
# including files that aren't intended to be part of the input, like
# temporary editor files or .license files.  So for all these reasons,
# only explicitly listed files are made available to s6-rc-compile.
build/s6-rc: $(HOST_S6_RC_FILES) $(HOST_S6_RC_BUILD_FILES)
	mkdir -p $$(dirname $@)
	rm -rf $@

	dir=$$(mktemp -d) && \
	    tar -c $(HOST_S6_RC_FILES) | \
	        tar -C $$dir -x --strip-components 1 && \
	    tar -c $(HOST_S6_RC_BUILD_FILES) | \
	        tar -C $$dir -x --strip-components 2 && \
	    s6-rc-compile $@ $$dir; \
	    exit=$$?; rm -rf $$dir; exit $$exit

build/host/netvm/data/vmlinux: $(VMLINUX)
	mkdir -p $$(dirname $@)
	cp $(VMLINUX) $@

# tar2ext4 will leave half a filesystem behind if it's interrupted
# half way through.
build/host/netvm/data/rootfs.ext4: build/rootfs.tar
	mkdir -p $$(dirname $@)
	tar2ext4 -i build/rootfs.tar -o $@.tmp
	mv $@.tmp $@

VM_FILES = \
	etc/dbus-1/system.conf \
	etc/fstab \
	etc/init \
	etc/mdev.conf \
	etc/mdev/iface \
	etc/nftables.conf \
	etc/passwd \
	etc/service/getty-ttyS0/run \
	etc/sysctl.conf

# These are separate because they need to be included, but putting
# them as make dependencies would confuse make.
VM_LINKS = bin var/run

VM_BUILD_FILES = build/etc/s6-rc
VM_MOUNTPOINTS = dev run proc sys var/lib/connman

build/rootfs.tar: $(PACKAGES_TAR) $(VM_FILES) $(VM_BUILD_FILES)
	cp --no-preserve=mode -f $(PACKAGES_TAR) $@
	tar $(TARFLAGS) --append -f $@ $(VM_FILES) $(VM_LINKS)
	echo $(VM_BUILD_FILES) | cut -d/ -f2 | \
	    tar $(TARFLAGS) --append -f $@ -C build -T -
	for m in $(VM_MOUNTPOINTS); do \
	    tar $(TARFLAGS) --append -hf $@ --xform="s,.*,$$m," /var/empty ; \
	done
	tar $(TARFLAGS) --append -hf $@ --xform='s,.*,etc/service,' /var/empty

VM_S6_RC_FILES = \
	etc/s6-rc/connman/dependencies \
	etc/s6-rc/connman/run \
	etc/s6-rc/connman/type \
	etc/s6-rc/dbus/notification-fd \
	etc/s6-rc/dbus/run \
	etc/s6-rc/dbus/type \
	etc/s6-rc/mdevd-coldplug/dependencies \
	etc/s6-rc/mdevd-coldplug/type \
	etc/s6-rc/mdevd-coldplug/up \
	etc/s6-rc/mdevd/notification-fd \
	etc/s6-rc/mdevd/run \
	etc/s6-rc/mdevd/type \
	etc/s6-rc/nftables/type \
	etc/s6-rc/nftables/up \
	etc/s6-rc/ok-all/contents \
	etc/s6-rc/ok-all/type \
	etc/s6-rc/sysctl/type \
	etc/s6-rc/sysctl/up

build/etc/s6-rc: $(VM_S6_RC_FILES)
	mkdir -p $$(dirname $@)
	rm -rf $@

	dir=$$(mktemp -d) && \
	    tar -c $(VM_S6_RC_FILES) | tar -C $$dir -x --strip-components 2 && \
	    s6-rc-compile $@ $$dir; \
	    exit=$$?; rm -r $$dir; exit $$exit

run: build/host/netvm/data/rootfs.ext4
	$(QEMU_KVM) -cpu host -machine q35,kernel=$(KERNEL) \
	  -drive file=build/host/netvm/data/rootfs.ext4,if=virtio,format=raw,readonly=on \
	  -append "console=ttyS0 root=/dev/vda" \
	  -netdev user,id=net0 \
	  -device e1000e,netdev=net0 \
	  -netdev user,id=net1 \
	  -device virtio-net,netdev=net1,mac=0A:B3:EC:80:00:00

clean:
	rm -rf build
.PHONY: clean
