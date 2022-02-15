# SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>
# SPDX-License-Identifier: MIT

{ pkgs ? import <nixpkgs> {} }: with pkgs;

mkShell {
  nativeBuildInputs = [ reuse rustfmt ];
}
