# SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>
# SPDX-License-Identifier: MIT

{ config ? import ../nix/eval-config.nix {} }: config.pkgs.callPackage (

{ bundlerApp }:

bundlerApp {
  pname = "jekyll";
  gemdir = ./.;
  exes = [ "jekyll" ];
}
) { }
