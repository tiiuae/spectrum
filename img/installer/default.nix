# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2021-2022 Alyssa Ross <hi@alyssa.is>

{ pkgs ? import <nixpkgs> {}, extraConfig ? {} }: with pkgs;

let
  inherit (builtins) head match storeDir;
  inherit (nixos {
    imports = [ ./configuration.nix extraConfig ];
  }) config;
in

{
  kernel = "${config.boot.kernelPackages.kernel}/${config.system.boot.loader.kernelFile}";

  initramfs = "${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile}";

  kernelParams = toString ([
    "init=${config.system.build.toplevel}/init"
  ] ++ config.boot.kernelParams);

  store = writeReferencesToFile config.system.build.toplevel;
}

