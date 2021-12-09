# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2021 Alyssa Ross <hi@alyssa.is>

{ modulesPath, pkgs, ... }:

let
  inherit (builtins) readFile;
in

{
  imports = [ (modulesPath + "/profiles/all-hardware.nix") ];

  boot.initrd.availableKernelModules = [ "squashfs" ];

  fileSystems."/" = { fsType = "tmpfs"; };
  fileSystems."/nix/store" = {
    device = "/dev/disk/by-partuuid/6e23b026-9f1e-479d-8a58-a0cda382e1ce";
  };

  services.cage.enable = true;
  services.cage.program = "gnome-image-installer";
  users.users.demo = { group = "demo"; isSystemUser = true; };
  users.groups.demo = {};
  security.polkit.extraConfig = readFile ./seat.rules;

  documentation.enable = false;

  boot.loader.systemd-boot.enable = true;

  environment.systemPackages = with pkgs; [
    (callPackage ./app { })
    gnome.adwaita-icon-theme
  ];

  systemd.tmpfiles.rules = [
    "L+ /var/lib/eos-image-defaults/vendor-customer-support.ini - - - - ${app/vendor-customer-support.ini}"
  ];
}
