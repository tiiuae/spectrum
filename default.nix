{ pkgs ? import <nixpkgs> {} }:

pkgs.callPackage (
{ newScope }:

let
  self = with self; {
    callPackage = newScope self;

    spectrum-live = callPackage ./live.nix { };

    host-rootfs = callPackage ./host-rootfs.nix { };
  };
in
self
) {}
