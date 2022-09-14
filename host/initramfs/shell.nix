# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2021-2022 Alyssa Ross <hi@alyssa.is>

{ config ? import ../../nix/eval-config.nix {} }:

let
  inherit (config) pkgs;
  inherit (pkgs.lib) cleanSource cleanSourceWith;

  extfs = pkgs.pkgsStatic.callPackage ./extfs.nix {
    inherit config;
  };
  rootfs = import ../rootfs { inherit config; };
  initramfs = import ./. { inherit config rootfs; };
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
