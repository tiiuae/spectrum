# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2021-2022 Alyssa Ross <hi@alyssa.is>

{ pkgs ? import <nixpkgs> {} }:

let
  inherit (pkgs.lib) cleanSource cleanSourceWith;

  extfs = pkgs.pkgsStatic.callPackage ./extfs.nix {
    inherit pkgs;
  };
  rootfs = import ../rootfs { inherit pkgs; };
  initramfs = import ./. { inherit pkgs rootfs; };
in

with pkgs;

initramfs.overrideAttrs ({ nativeBuildInputs ? [], ... }: {
  nativeBuildInputs = nativeBuildInputs ++ [
    cryptsetup qemu_kvm util-linux
  ];

  EXT_FS = extfs;
  KERNEL = "${rootfs.kernel}/${stdenv.hostPlatform.linux-kernel.target}";
  ROOT_FS = rootfs;
})
