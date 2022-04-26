# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>

{ pkgs ? import <nixpkgs> {} }: pkgs.callPackage (
{ lib, stdenv, fetchpatch, meson, ninja, rustc }:

let
  inherit (lib) cleanSource;
in

stdenv.mkDerivation {
  name = "start-vm";

  src = cleanSource ./.;

  nativeBuildInputs = [ meson ninja rustc ];

  doCheck = true;
}
) { }
