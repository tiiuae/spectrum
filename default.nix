{ pkgs ? import <nixpkgs> {} }:

pkgs.callPackage (
{ newScope }:

let
  self = with self; {
    callPackage = newScope self;

    spectrum-live = callPackage ./live.nix { };

    initramfs = callPackage ./initramfs.nix { };

    host-rootfs = import ../spectrum-rootfs { inherit pkgs; };

    extfs = pkgs.pkgsStatic.callPackage ./extfs.nix { inherit pkgs; };
  };
in
self
) {}
