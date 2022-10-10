# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2021-2022 Alyssa Ross <hi@alyssa.is>

{ config ? import ../../../nix/eval-config.nix {} }:

import ../make-vm.nix { inherit config; } {
  providers.net = [ "netvm" ];
  run = config.pkgs.pkgsStatic.callPackage (
    { writeScript, lynx }:
    writeScript "run-lynx" ''
      #!/bin/execlineb -P
      ${lynx}/bin/lynx https://spectrum-os.org
    ''
  ) { };
}
