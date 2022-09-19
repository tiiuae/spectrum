# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2021-2022 Alyssa Ross <hi@alyssa.is>

{ config ? import ../../../nix/eval-config.nix {} }:

import ../../vm-lib/make-vm.nix { inherit config; } {
  name = "appvm-lynx";
  providers.net = [ "netvm" ];
  run = config.pkgs.pkgsStatic.callPackage (
    { writeScript, lynx }:
    writeScript "run-lynx" ''
      #!/bin/execlineb -P
      ${lynx}/bin/lynx https://spectrum-os.org
    ''
  ) { };
}
