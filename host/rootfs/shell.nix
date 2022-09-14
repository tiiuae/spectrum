# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2021 Alyssa Ross <hi@alyssa.is>
# SPDX-FileCopyrightText: 2022 Unikie

{ config ? import ../../nix/eval-config.nix {} }:

let
  rootfs = import ./. { inherit config; };
in

with config.pkgs;

rootfs.overrideAttrs (
{ passthru ? {}, nativeBuildInputs ? [], ... }:

{
  nativeBuildInputs = nativeBuildInputs ++ [
    cryptsetup jq netcat qemu_kvm reuse util-linux
  ];

  EXT_FS = pkgsStatic.callPackage ../initramfs/extfs.nix { inherit config; };
  INITRAMFS = import ../initramfs { inherit config rootfs; };
  KERNEL = "${passthru.kernel}/${stdenv.hostPlatform.linux-kernel.target}";
})
