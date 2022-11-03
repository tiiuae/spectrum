# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is><
# SPDX-FileCopyrightText: 2022 Unikie

{ config }:

import ../../vm-lib/make-vm.nix { inherit config; } {
    name = "appvm-foot";
    wayland = true;
    run = config.pkgs.callPackage (
      { writeScript, foot, wayland-proxy-virtwl }:
      writeScript "appvm-foot-run" ''
        #!/bin/execlineb -P
        if { modprobe virtio-gpu }
        foreground { ln -ns /run/ext /run/opengl-driver }
        foreground { mkdir /run/user }
        foreground {
          umask 077
          mkdir /run/user/0
        }
        export XDG_RUNTIME_DIR /run/user/0
        ${wayland-proxy-virtwl}/bin/wayland-proxy-virtwl --virtio-gpu
        ${foot}/bin/foot
      ''
    ) {};
}
