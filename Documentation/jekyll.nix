# SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>
# SPDX-License-Identifier: MIT

{ pkgs ? import <nixpkgs> {} }: pkgs.callPackage (

{ bundlerApp }:

bundlerApp {
  pname = "jekyll";
  gemdir = ./.;
  exes = [ "jekyll" ];
}
) { }
