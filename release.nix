# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>

# This file is built to populate the binary cache.

{ pkgs ? import <nixpkgs> {} }:

{
  doc = import ./Documentation { inherit pkgs; };

  combined = import img/combined/run-vm.nix { inherit pkgs; };
}
