# SPDX-License-Identifier: EUPL-1.2
# SPDX-FileCopyrightText: 2021 Alyssa Ross <hi@alyssa.is>

{ pkgs ? import <nixpkgs> {} }:

with pkgs;

(import ./. { inherit pkgs; }).overrideAttrs (
{ passthru ? {}, nativeBuildInputs ? [], ... }:

{
  nativeBuildInputs = nativeBuildInputs ++ [
    jq netcat qemu_kvm reuse screen util-linux
  ];

  KERNEL = "${passthru.kernel}/${stdenv.hostPlatform.linux-kernel.target}";
})
