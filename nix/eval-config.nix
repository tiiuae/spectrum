# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2022 Unikie

{ config ?
  if builtins.pathExists ../config.nix then import ../config.nix else {}
}:

({ pkgs ? import <nixpkgs> {} }: {
  inherit pkgs;
}) config
