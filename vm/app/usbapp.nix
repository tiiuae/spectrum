# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2021-2022 Alyssa Ross <hi@alyssa.is>
#
# Don't work due to "new" VMs implementation restrictions 

{ config ? import ../../../nix/eval-config.nix {} }:

import ../../vm-lib/make-vm.nix { inherit config; } {
  name = "appvm-uabapp";
  providers.net = [ "netvm" ];
  run = config.pkgs.pkgsStatic.callPackage (
    { writeScript, bash, usbutils }:
    writeScript "run-lola-run" ''
      #!/bin/execlineb -P

      foreground { sh -c "cd /run && nohup /usr/bin/__i &" }

      if { /etc/mdev/wait network-online }
      ${bash}/bin/bash 
    ''
  ) { };
}
  