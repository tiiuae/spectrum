# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2021-2022 Alyssa Ross <hi@alyssa.is>

{ lib, modulesPath, pkgs, ... }:

let
  inherit (builtins) readFile;
in

{
  imports = [ (modulesPath + "/profiles/all-hardware.nix") ];

  boot.consoleLogLevel = 2;
  boot.kernelParams = [ "udev.log_priority=5" ];
  boot.initrd.verbose = false;

  boot.plymouth.enable = true;
  boot.plymouth.logo = pkgs.callPackage (
    { lib, runCommand, fetchurl, inkscape }:
    runCommand "spectrum-logo.png" {
      nativeBuildInputs = [ inkscape ];
      svg = fetchurl {
        url = "https://spectrum-os.org/git/www/plain/logo/logo_mesh.svg?id=5ac2d787b12e05a9ea91e94ca9373ced55d7371a";
        sha256 = "1k5025nc5mxdls7bw7wk1734inadvibqxvg8b8yg6arr3y9yy46k";
      };
    } ''
      inkscape -w 48 -h 48 -o "$out" "$svg"
    ''
  ) {};

  fileSystems."/" = { fsType = "tmpfs"; };

  services.cage.enable = true;
  services.cage.program =
    "${pkgs.callPackage ./app {}}/bin/gnome-image-installer";
  users.users.demo = { group = "demo"; isSystemUser = true; };
  users.groups.demo = {};
  security.polkit.extraConfig = readFile ./seat.rules;

  services.udisks2.enable = true;

  documentation.enable = false;
  networking.firewall.enable = false;
  networking.resolvconf.enable = false;
  nix.enable = false;
  services.timesyncd.enable = false;

  boot.loader.systemd-boot.enable = true;

  environment.systemPackages = with pkgs; [ gnome.adwaita-icon-theme ];

  systemd.tmpfiles.rules = [
    "L+ /var/lib/eos-image-defaults/vendor-customer-support.ini - - - - ${app/vendor-customer-support.ini}"
  ];

  system.stateVersion = lib.trivial.release;
}
