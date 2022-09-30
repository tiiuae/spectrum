# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>

{ config ? import ../nix/eval-config.nix {} }:
config.pkgs.pkgsStatic.callPackage (

{ lib, runCommand, writeReferencesToFile, e2fsprogs, tar2ext4 }:

{ name, run, providers ? {} }:

let
  inherit (lib)
    any attrValues concatLists concatStrings hasInfix mapAttrsToList;

  basePackages = (import ../img/app { inherit config; }).packagesSysroot;
in

assert !(any (hasInfix "\n") (concatLists (attrValues providers)));

runCommand "spectrum-vm-${name}" {
  nativeBuildInputs = [ e2fsprogs tar2ext4 ];

  providerDirs = concatStrings (concatLists
    (mapAttrsToList (kind: map (vm: "${kind}/${vm}\n")) providers));
  passAsFile = [ "providerDirs" ];
} ''
  mkdir -p "$out"/data/${name}/{blk,providers}

  mkdir root
  cd root
  ln -s ${run} run
  ln -s ${config.pkgs.mesa.drivers}/lib
  comm -23 <(sort -u ${writeReferencesToFile run} ${writeReferencesToFile config.pkgs.mesa.drivers}) \
      <(sort ${writeReferencesToFile basePackages}) |
      tar -cf ../run.tar --verbatim-files-from -T - *
  tar2ext4 -i ../run.tar -o "$out/data/${name}/blk/run.img"
  e2label "$out/data/${name}/blk/run.img" ext

  pushd "$out/data/${name}/providers"
  xargs -rd '\n' dirname -- < "$providerDirsPath" | xargs -rd '\n' mkdir -p --
  xargs -rd '\n' touch -- < "$providerDirsPath"
  popd

  ln -s /usr/img/appvm/blk/root.img "$out/data/${name}/blk"
  ln -s /usr/img/appvm/vmlinux "$out/data/${name}"
''
) {}
