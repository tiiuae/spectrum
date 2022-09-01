# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2021 Alyssa Ross <hi@alyssa.is>
# SPDX-FileCopyrightText: 2022 Unikie

{ pkgs ? import <nixpkgs> {} }:

let
  rootfs = import ./. { inherit pkgs; };
in

with pkgs;

rootfs.overrideAttrs (
{ passthru ? {}, nativeBuildInputs ? [], ... }:

{
  nativeBuildInputs = nativeBuildInputs ++ [
    cryptsetup jq netcat qemu_kvm reuse util-linux
  ];

  EXT_FS = pkgsStatic.callPackage ../initramfs/extfs.nix { inherit pkgs; };
  INITRAMFS = import ../initramfs { inherit pkgs rootfs; };
  KERNEL = "${passthru.kernel}/${stdenv.hostPlatform.linux-kernel.target}";
})
