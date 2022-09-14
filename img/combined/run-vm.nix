# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2021 Alyssa Ross <hi@alyssa.is>

{ config ? import ../../nix/eval-config.nix {} }: with config.pkgs;

let
  image = import ./. { inherit config; };
in

writeShellScript "run-spectrum-installer-vm.sh" ''
  export PATH=${lib.makeBinPath [ coreutils qemu_kvm ]}
  img="$(mktemp spectrum-installer-target.XXXXXXXXXX.img)"
  truncate -s 10G "$img"
  exec 3<>"$img"
  rm -f "$img"
  exec qemu-kvm -cpu host -m 4G -machine q35 -snapshot \
    -display gtk,gl=on \
    -device virtio-vga-gl \
    -device qemu-xhci \
    -device usb-storage,drive=drive1,removable=true \
    -drive file=${qemu_kvm}/share/qemu/edk2-${stdenv.hostPlatform.qemuArch}-code.fd,format=raw,if=pflash,readonly=true \
    -drive file=${image},id=drive1,format=raw,if=none,readonly=true \
    -drive file=/proc/self/fd/3,format=raw,if=virtio
''
