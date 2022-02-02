# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>

{ pkgs ? import <nixpkgs> {} }: pkgs.callPackage (
{ pkgsBuildHost, lib, stdenv, fetchpatch, rust, ninja, rustc }:

let
  inherit (lib) cleanSource;

  meson' = pkgsBuildHost.meson_0_60.overrideAttrs ({ patches ? [], ... }: {
    patches = patches ++ [
      (fetchpatch {
        url = "https://github.com/alyssais/meson/commit/e8464d47fa8971098d626744b14db5d066ebf753.patch";
        sha256 = "0naxj0s16w6ffk6d7xg1m6kkx2a7zd0hz8mbvn70xy1k12a0c5gy";
      })
    ];
  });
in

stdenv.mkDerivation {
  name = "start-vm";

  src = cleanSource ./.;

  nativeBuildInputs = [ meson' ninja rustc ];

  dontStrip = true;
}
) { }
