# SPDX-License-Identifier: EUPL-1.2
# SPDX-FileCopyrightText: 2021 Alyssa Ross <hi@alyssa.is>

{ pkgs ? import <nixpkgs> {} }:

with pkgs;

let
  kernel = linux.override {
    structuredExtraConfig = with lib.kernel; {
      VIRTIO = yes;
      VIRTIO_PCI = yes;
      VIRTIO_BLK = yes;
      EXT4_FS = yes;
    };
  };
in

(import ./. { inherit pkgs; }).overrideAttrs (
{ passthru ? {}, nativeBuildInputs ? [], ... }:

{
  nativeBuildInputs = nativeBuildInputs ++ [ qemu_kvm ];

  KERNEL = "${kernel}/${stdenv.hostPlatform.linux-kernel.target}";

  passthru = passthru // { inherit kernel; };
})
