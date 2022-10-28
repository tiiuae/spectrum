# SPDX-FileCopyrightText: 2021-2022 Alyssa Ross <hi@alyssa.is>
# SPDX-License-Identifier: MIT

{ config, runCommand, tar2ext4 }:

let
  netvm = import ../../vm/sys/net {
    inherit config;
    # inherit (foot) terminfo;
  };

  appvm-catgirl = import ../../vm/app/catgirl.nix { inherit config; };
  appvm-hello-wayland = import ../../vm/app/hello-wayland.nix { inherit config; };
  appvm-lynx = import ../../vm/app/lynx.nix { inherit config; };
  appvm-usbapp = import ../../vm/app/usbapp.nix { inherit config; };
  appvm-usb = import ../../vm/app/usb { inherit config; };

in

runCommand "ext.ext4" {
  nativeBuildInputs = [ tar2ext4 ];
} ''
  mkdir svc

  tar -C ${netvm} -c data | tar -C svc -x
  chmod +w svc/data
  tar -C ${appvm-catgirl} -c data | tar -C svc -x
  chmod +w svc/data
  tar -C ${appvm-hello-wayland} -c data | tar -C svc -x
  chmod +w svc/data
  tar -C ${appvm-lynx} -c data | tar -C svc -x
  chmod +w svc/data
  tar -C ${appvm-usbapp} -c data | tar -C svc -x
  chmod +w svc/data
  tar -C ${appvm-usb} -c data | tar -C svc -x



  tar -cf ext.tar svc
  tar2ext4 -i ext.tar -o $out
''
