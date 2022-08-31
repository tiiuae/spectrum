# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>

{ config ? import ../../nix/eval-config.nix {} }: config.pkgs.callPackage (
{ lib, stdenv, fetchpatch, meson, ninja, rustc }:

let
  inherit (lib) cleanSource cleanSourceWith hasSuffix;
in

stdenv.mkDerivation {
  name = "start-vm";

  src = cleanSourceWith {
    filter = name: _type: !(hasSuffix ".nix" name);
    src = cleanSource ./.;
  };

  nativeBuildInputs = [ meson ninja rustc ];

  doCheck = true;
}
) { }
