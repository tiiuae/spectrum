# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2021-2022 Alyssa Ross <hi@alyssa.is>

{ config ? import ../../../nix/eval-config.nix {} }:

import ../make-vm.nix { inherit config; } {
  providers.net = [ "netvm" ];
  run = config.pkgs.pkgsStatic.callPackage (
    { writeScript, catgirl }:
    writeScript "run-catgirl" ''
      #!/bin/execlineb -P
      foreground { printf "IRC nick (to join #spectrum): " }
      backtick -E nick { head -1 }
      ${catgirl}/bin/catgirl -h irc.libera.chat -j "#spectrum" -n $nick
    ''
  ) { };
}
