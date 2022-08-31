# SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>
# SPDX-License-Identifier: MIT

{ config ? import nix/eval-config.nix {} }: with config.pkgs;

mkShell {
  nativeBuildInputs = [ reuse rustfmt ];
}
