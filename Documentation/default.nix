# SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>
# SPDX-License-Identifier: MIT

{ pkgs ? import <nixpkgs> {} }: pkgs.callPackage (

{ lib, stdenv, asciidoctor }:

let
  inherit (lib) cleanSource cleanSourceWith hasSuffix;
in

stdenv.mkDerivation {
  name = "spectrum-doc";

  src = cleanSourceWith {
    filter = name: _type: !(hasSuffix name ".html");
    src = cleanSource ./.;
  };

  nativeBuildInputs = [ asciidoctor ];

  makeFlags = [ "prefix=$(out)" ];

  enableParallelBuilding = true;
}

) { }
