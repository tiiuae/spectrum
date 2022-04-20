# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2021-2022 Alyssa Ross <hi@alyssa.is>

{ pkgs ? import <nixpkgs> {} }:

with pkgs;

(import ./. { inherit pkgs; }).overrideAttrs ({ nativeBuildInputs ? [], ... }: {
  nativeBuildInputs = nativeBuildInputs ++ [ qemu_kvm ];

  OVMF_FD = "${OVMF.fd}/FV/OVMF.fd";
})
