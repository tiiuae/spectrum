# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2021 Alyssa Ross <hi@alyssa.is>

{ pkgs ? import <nixpkgs> {} }:

with pkgs;

(import ./. { inherit pkgs; }).overrideAttrs (
{ nativeBuildInputs ? [], ... }:

{
  nativeBuildInputs = nativeBuildInputs ++ [ rustfmt ];
})
