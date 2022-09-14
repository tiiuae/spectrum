# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>

{ config ? import ../nix/eval-config.nix {} }:

let
  inherit (config.pkgs.lib) cleanSource cleanSourceWith hasSuffix;
in

cleanSourceWith {
  src = cleanSource ./.;
  filter = name: _type: !(hasSuffix ".nix" name);
}
