# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2021 Alyssa Ross <hi@alyssa.is>

{ pkgs ? import <nixpkgs> {} }: with pkgs;

let
  image = import ./. { inherit pkgs; };
in

writeShellScript "run-spectrum-installer-vm.sh" ''
  img="$(mktemp spectrum-installer-target.XXXXXXXXXX.img)"
  truncate -s 10G "$img"
  exec 3<>"$img"
  rm -f "$img"
  exec ${qemu_kvm}/bin/qemu-kvm -cpu host -m 4G -machine q35 -snapshot \
    -display gtk,gl=on \
    -device virtio-vga-gl \
    -bios ${OVMF.fd}/FV/OVMF.fd \
    -device qemu-xhci \
    -device usb-storage,drive=drive1,removable=true \
    -drive file=${image},id=drive1,format=raw,if=none,readonly=true \
    -drive file=/proc/self/fd/3,format=raw,if=virtio
''
