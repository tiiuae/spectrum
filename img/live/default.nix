# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2021-2022 Alyssa Ross <hi@alyssa.is>

{ pkgs ? import <nixpkgs> {} }:

let
  inherit (pkgs.lib) cleanSource cleanSourceWith hasSuffix;

  extfs = pkgs.pkgsStatic.callPackage ../../host/initramfs/extfs.nix {
    inherit pkgs;
  };
  rootfs = import ../../host/rootfs { inherit pkgs; };
  scripts = import ../../scripts { inherit pkgs; };
  initramfs = import ../../host/initramfs { inherit pkgs rootfs; };
in

with pkgs;

stdenvNoCC.mkDerivation {
  name = "spectrum-live.img";

  src = cleanSourceWith {
    filter = name: _type:
      name != "${toString ./.}/build" &&
      !(hasSuffix ".nix" name);
    src = cleanSource ./.;
  };

  nativeBuildInputs = [ cryptsetup dosfstools jq mtools util-linux ];

  EXT_FS = extfs;
  INITRAMFS = initramfs;
  KERNEL = "${rootfs.kernel}/${stdenv.hostPlatform.linux-kernel.target}";
  ROOT_FS = rootfs;
  SYSTEMD_BOOT_EFI = "${systemd}/lib/systemd/boot/efi/systemd-bootaa64.efi";

  buildFlags = [ "build/live.img" ];
  makeFlags = [ "SCRIPTS=${scripts}" ];

  installPhase = ''
    runHook preInstall
    mv build/live.img $out
    runHook postInstall
  '';

  enableParallelBuilding = true;
}
