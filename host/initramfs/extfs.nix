# SPDX-FileCopyrightText: 2021-2022 Alyssa Ross <hi@alyssa.is>
# SPDX-License-Identifier: MIT

{ config, runCommand, tar2ext4 }:

let
  netvm = import ../../vm/sys/net {
    inherit config;
    # inherit (foot) terminfo;
  };

  appvm-catgirl = import ../../vm/app/catgirl.nix { inherit config; };
  appvm-lynx = import ../../vm/app/lynx.nix { inherit config; };
in

runCommand "ext.ext4" {
  nativeBuildInputs = [ tar2ext4 ];
} ''
  mkdir svc

  tar -C ${netvm} -c data | tar -C svc -x
  chmod +w svc/data
  tar -C ${appvm-catgirl} -c data | tar -C svc -x
  chmod +w svc/data
  tar -C ${appvm-lynx} -c data | tar -C svc -x

  tar -cf ext.tar svc
  tar2ext4 -i ext.tar -o $out
''
