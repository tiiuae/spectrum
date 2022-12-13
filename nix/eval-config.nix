# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2022 Unikie

{ config ?
  let customPath = builtins.tryEval <spectrum-config/config.nix>; in
  if customPath.success then import customPath.value
  else if builtins.pathExists ../config.nix then import ../config.nix
  else {}
}:

({ pkgs ? import <nixpkgs> {} }: {
  inherit pkgs;
}) config
