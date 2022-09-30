# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2022 Unikie

{ config ? import ../../../nix/eval-config.nix {} }:

import ../../vm-lib/make-vm.nix { inherit config; } {
  name = "appvm-hello-wayland";
  wayland = true;
  run = config.pkgs.callPackage (
    { writeScript, hello-wayland, wayland-proxy-virtwl }:
    writeScript "run-hello-wayland" ''
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
      ${hello-wayland}/bin/hello-wayland
    ''
  ) { };
}
