# SPDX-FileCopyrightText: 2021-2022 Alyssa Ross <hi@alyssa.is>
# SPDX-License-Identifier: MIT

{ pkgs, runCommand, s6-rc, tar2ext4 }:

let
  netvm = import ../../vm/sys/net {
    inherit pkgs;
    # inherit (foot) terminfo;
  };

  appvm-catgirl = import ../../vm/app/catgirl {
    inherit pkgs;
    # inherit (foot) terminfo;
  };

  appvm-lynx = import ../../vm/app/lynx {
    inherit pkgs;
    # inherit (foot) terminfo;
  };
in

runCommand "ext.ext4" {
  nativeBuildInputs = [ tar2ext4 s6-rc ];
} ''
  mkdir s6-rc svc

  tar -C ${netvm}/s6-rc -c . | tar -C s6-rc -x
  chmod +w s6-rc
  tar -C ${appvm-catgirl}/s6-rc -c . | tar -C s6-rc -x
  chmod +w s6-rc
  tar -C ${appvm-lynx}/s6-rc -c . | tar -C s6-rc -x
  chmod +w s6-rc
  mkdir s6-rc/default
  echo bundle > s6-rc/default/type
  printf "appvm-catgirl\nappvm-lynx\n" > s6-rc/default/contents
  s6-rc-compile svc/s6-rc s6-rc

  tar -C ${netvm} -c data | tar -C svc -x
  chmod +w svc/data
  tar -C ${appvm-catgirl} -c data | tar -C svc -x
  chmod +w svc/data
  tar -C ${appvm-lynx} -c data | tar -C svc -x

  tar -cf ext.tar svc
  tar2ext4 -i ext.tar -o $out
''
