# SPDX-License-Identifier: EUPL-1.2
# SPDX-FileCopyrightText: 2021 Alyssa Ross <hi@alyssa.is>

# qemu-kvm is non-standard, but is present in at least Fedora and
# Nixpkgs.  If you don't have qemu-kvm, you'll need to set e.g.
# QEMU_KVM = qemu-system-x86_64 -enable-kvm.
QEMU_KVM = qemu-kvm
CLOUD_HYPERVISOR = cloud-hypervisor
SCREEN = screen

VMM = qemu

TARFLAGS = -v --show-transformed-names

# tar2ext4 will leave half a filesystem behind if it's interrupted
# half way through.
build/rootfs.ext4: build/rootfs.tar
	tar2ext4 -i build/rootfs.tar -o $@.tmp
	mv $@.tmp $@

FILES = \
	etc/fstab \
	etc/group \
	etc/init \
	etc/login/kind/hvc \
	etc/login/kind/tty \
	etc/login/kind/ttyS \
	etc/login/share/prelude \
	etc/login/share/sh \
	etc/login/share/tmux \
	etc/mdev.conf \
	etc/passwd \
	etc/service/getty-hvc0/run \
	etc/service/getty-tty1/run \
	etc/service/getty-tty2/run \
	etc/service/getty-tty3/run \
	etc/service/getty-tty4/run \
	etc/service/getty-ttyS0/run

BUILD_FILES = build/etc/s6-rc
MOUNTPOINTS = dev run proc sys

build/rootfs.tar: $(PACKAGES_TAR) $(FILES) $(BUILD_FILES)
	cp --no-preserve=mode -f $(PACKAGES_TAR) $@
	tar $(TARFLAGS) --append -f $@ $(FILES)
	echo $(BUILD_FILES) | cut -d/ -f2 | \
	    tar $(TARFLAGS) --append -f $@ -C build -T -
	for m in $(MOUNTPOINTS); do \
	    tar $(TARFLAGS) --append -hf $@ --xform="s,.*,$$m," /var/empty ; \
	done
	tar $(TARFLAGS) --append -hf $@ --xform='s,.*,etc/service,' /var/empty

S6_RC_FILES = \
	etc/s6-rc/hello/type \
	etc/s6-rc/hello/up \
	etc/s6-rc/mdevd-coldplug/dependencies \
	etc/s6-rc/mdevd-coldplug/type \
	etc/s6-rc/mdevd-coldplug/up \
	etc/s6-rc/mdevd/notification-fd \
	etc/s6-rc/mdevd/run \
	etc/s6-rc/mdevd/type \
	etc/s6-rc/ok-all/contents \
	etc/s6-rc/ok-all/type

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

run-qemu: build/rootfs.ext4
	$(QEMU_KVM) -cpu host -m 6G \
	    -qmp unix:vmm.sock,server,nowait \
	    -drive file=build/rootfs.ext4,if=virtio,format=raw,readonly=on \
	    -kernel $(KERNEL) \
	    -append "console=ttyS0 root=/dev/vda" \
	    -chardev pty,id=virtiocon0 \
	    -device virtio-serial-pci \
	    -device virtconsole,chardev=virtiocon0
.PHONY: run-qemu

run-cloud-hypervisor: build/rootfs.ext4
	$(CLOUD_HYPERVISOR) \
	    --memory size=6G \
	    --api-socket path=vmm.sock \
	    --disk path=build/rootfs.ext4,readonly=on \
	    --kernel $(KERNEL) \
	    --cmdline "console=ttyS0 root=/dev/vda" \
	    --console pty
.PHONY: run-cloud-hypervisor

run: run-$(VMM)
.PHONY: run

console:
	@$(SCREEN) "$$(scripts/$(VMM)-pty.sh vmm.sock virtiocon0)"
.PHONY: console
