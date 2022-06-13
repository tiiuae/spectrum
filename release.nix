# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>

# This file is built to populate the binary cache.

{ pkgs ? import <nixpkgs> {} }:

{
  combined = import img/combined/run-vm.nix { inherit pkgs; };

  aarch64-musl-bootstrap =
    (import (pkgs.path + "/pkgs/stdenv/linux/make-bootstrap-tools.nix") {
      pkgs = pkgs.pkgsCross.aarch64-multiplatform.pkgsMusl;
    }).build;
}
