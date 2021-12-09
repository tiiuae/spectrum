# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2021 Alyssa Ross <hi@alyssa.is>

{ pkgs, ... }:

let
  inherit (builtins) readFile;
in

{
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

  boot.loader.systemd-boot.enable = true;

  environment.systemPackages = with pkgs; [
    (callPackage ./installer.nix { })
    gnome.adwaita-icon-theme
  ];

  systemd.tmpfiles.rules = [
    "L+ /var/lib/eos-image-defaults/vendor-customer-support.ini - - - - ${pkgs.writeText "vendor-customer-support.ini" ''
      [Customer Support]
      Email = discuss@spectrum-os.org
    ''}"
  ];
}
