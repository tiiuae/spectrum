# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>

{ config ? import ../nix/eval-config.nix {} }:

import ../vm-lib/make-vm.nix {
  inherit (config) pkgs;
  basePaths = (import ../img/app { inherit config; }).packagesSysroot;
}
