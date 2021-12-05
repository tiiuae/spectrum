# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2021 Alyssa Ross <hi@alyssa.is>

{ pkgs, ... }:

{
  imports = [
    <nixpkgs/nixos/modules/installer/cd-dvd/installation-cd-graphical-gnome.nix>
  ];

  boot.loader.systemd-boot.enable = true;

  environment.systemPackages = with pkgs; [
    (callPackage ./installer.nix { })
  ];

  systemd.tmpfiles.rules = [
    "L+ /var/lib/eos-image-defaults/vendor-customer-support.ini - - - - ${pkgs.writeText "vendor-customer-support.ini" ''
      [Customer Support]
      Email = discuss@spectrum-os.org
    ''}"
  ];
}
