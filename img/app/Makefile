# SPDX-License-Identifier: EUPL-1.2+
# SPDX-FileCopyrightText: 2021-2022 Alyssa Ross <hi@alyssa.is>

# qemu-kvm is non-standard, but is present in at least Fedora and
# Nixpkgs.  If you don't have qemu-kvm, you'll need to set e.g.
# QEMU_KVM = qemu-system-x86_64 -enable-kvm.
QEMU_KVM = qemu-kvm
CLOUD_HYPERVISOR = cloud-hypervisor
CROSVM = crosvm
CROSVM_DEVICE_GPU = $(CROSVM) device gpu
CROSVM_RUN = $(CROSVM) run

prefix = /usr/local
imgdir = $(prefix)/img

VMM = qemu
SCRIPTS = ../../scripts

HOST_BUILD_FILES = \
	build/host/appvm/blk/root.img \
	build/host/appvm/Image

all: $(HOST_BUILD_FILES)
.PHONY: all

install: $(HOST_BUILD_FILES)
	mkdir -p $(imgdir)
	tar -c $(HOST_BUILD_FILES) | tar -C $(imgdir) -x --strip-components 2
.PHONY: install

build/host/appvm/Image: $(IMAGE)
	mkdir -p $$(dirname $@)
	cp $(IMAGE) $$(dirname $@)/Image

build/host/appvm/blk/root.img: $(SCRIPTS)/make-gpt.sh $(SCRIPTS)/sfdisk-field.awk build/rootfs.ext4
	mkdir -p $$(dirname $@)
	$(SCRIPTS)/make-gpt.sh $@.tmp \
	    build/rootfs.ext4:4f68bce3-e8cd-4db1-96e7-fbcaf984b709:5460386f-2203-4911-8694-91400125c604:root
	mv $@.tmp $@

# tar2ext4 will leave half a filesystem behind if it's interrupted
# half way through.
build/rootfs.ext4: build/rootfs.tar
	mkdir -p $$(dirname $@)
	tar2ext4 -i build/rootfs.tar -o $@.tmp
	mv $@.tmp $@

VM_FILES = \
	etc/fstab \
	etc/init \
	etc/mdev.conf \
	etc/mdev/iface \
	etc/mdev/listen \
	etc/mdev/wait \
	etc/passwd \
	etc/resolv.conf \
	etc/s6-linux-init/scripts/rc.init
VM_DIRS = dev run proc sys \
	etc/s6-linux-init/env \
	etc/s6-linux-init/run-image/ext \
	etc/s6-linux-init/run-image/service

# These are separate because they need to be included, but putting
# them as make dependencies would confuse make.
VM_LINKS = bin etc/ssl/certs/ca-certificates.crt

VM_BUILD_FILES = build/etc/s6-rc

build/empty:
	mkdir -p $@

build/rootfs.tar: build/empty $(PACKAGES_TAR) $(VM_FILES) $(VM_BUILD_FILES)
	cp --no-preserve=mode -f $(PACKAGES_TAR) $@
	tar $(TARFLAGS) --append -f $@ $(VM_FILES) $(VM_LINKS)
	echo $(VM_BUILD_FILES) | cut -d/ -f2 | \
	    tar $(TARFLAGS) --append -f $@ -C build -T -
	for m in $(VM_DIRS); do \
	    tar $(TARFLAGS) --append -hf $@ --xform="s,.*,$$m," build/empty ; \
	done

VM_S6_RC_FILES = \
	etc/s6-rc/app/run \
	etc/s6-rc/app/type \
	etc/s6-rc/mdevd-coldplug/dependencies \
	etc/s6-rc/mdevd-coldplug/type \
	etc/s6-rc/mdevd-coldplug/up \
	etc/s6-rc/mdevd/notification-fd \
	etc/s6-rc/mdevd/run \
	etc/s6-rc/mdevd/type \
	etc/s6-rc/ok-all/contents \
	etc/s6-rc/ok-all/type

build/etc/s6-rc: $(VM_S6_RC_FILES)
	mkdir -p $$(dirname $@)
	rm -rf $@

	dir=$$(mktemp -d) && \
	    tar -c $(VM_S6_RC_FILES) | tar -C $$dir -x --strip-components 2 && \
	    s6-rc-compile $@ $$dir; \
	    exit=$$?; rm -r $$dir; exit $$exit

start-vhost-user-gpu:
	rm -f vhost-user-gpu.sock
	$(CROSVM_DEVICE_GPU) \
	    --socket vhost-user-gpu.sock \
	    --wayland-sock "$$XDG_RUNTIME_DIR/$$WAYLAND_DISPLAY" \
	    --params '{"context-types":"cross-domain"}' &
	while ! [ -S vhost-user-gpu.sock ]; do
	    sleep 1
	done
.PHONY: start-vhost-user-gpu

run-qemu: build/host/appvm/blk/root.img
	$(QEMU_KVM) -m 128 -cpu host -machine q35,kernel=$(KERNEL) -vga none \
	  -drive file=build/host/appvm/blk/root.img,if=virtio,format=raw,readonly=on \
	  -drive file=$(RUN_IMG),if=virtio,format=raw,readonly=on \
	  -append "console=ttyS0 root=PARTLABEL=root" \
	  -netdev user,id=net0 \
	  -device virtio-net,netdev=net0,mac=0A:B3:EC:00:00:00 \
	  -chardev vc,id=virtiocon0 \
	  -device virtio-serial-pci \
	  -device virtconsole,chardev=virtiocon0
.PHONY: run-qemu

run-cloud-hypervisor: build/host/appvm/blk/root.img start-vhost-user-gpu
	$(CLOUD_HYPERVISOR) \
	    --api-socket path=vmm.sock \
	    --memory size=128M,shared=on \
	    --disk path=build/host/appvm/blk/root.img,readonly=on \
	           path=$(RUN_IMG),readonly=on \
	    --net tap=tap0,mac=0A:B3:EC:00:00:00 \
	    --gpu socket=vhost-user-gpu.sock \
	    --kernel $(KERNEL) \
	    --cmdline "console=ttyS0 root=PARTLABEL=root" \
	    --console tty \
	    --serial pty
.PHONY: run-cloud-hypervisor

run-crosvm: build/host/appvm/blk/root.img start-vhost-user-gpu
	$(CROSVM_RUN) \
	    --disk build/host/appvm/blk/root.img \
	    --disk $(RUN_IMG) \
	    -p "console=ttyS0 root=PARTLABEL=root" \
	    --vhost-user-gpu vhost-user-gpu.sock \
	    --serial type=file,hardware=serial,path=/tmp/crosvm.log \
	    --serial type=stdout,hardware=virtio-console,stdin=true \
	    $(KERNEL)
.PHONY: run-crosvm

run: run-$(VMM)
.PHONY: run

clean:
	rm -rf build
.PHONY: clean
