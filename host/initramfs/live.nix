# SPDX-License-Identifier: EUPL-1.2
# SPDX-FileCopyrightText: 2021-2022 Alyssa Ross <hi@alyssa.is>

{ pkgs ? import <nixpkgs> {} }:

let
  extfs = pkgs.pkgsStatic.callPackage ./extfs.nix { inherit pkgs; };
  rootfs = import ../rootfs { inherit pkgs; };
  initramfs = import ./. { inherit pkgs rootfs; };
in

with pkgs;

initramfs.overrideAttrs ({ buildFlags ? "", nativeBuildInputs ? [], ... }: {
  name = "spectrum-live.img";

  nativeBuildInputs = nativeBuildInputs ++ [
    cryptsetup dosfstools jq mtools util-linux
  ];

  EFI_STUB = "${systemd}/lib/systemd/boot/efi/linuxx64.efi.stub";
  EXT_FS = extfs;
  KERNEL = "${rootfs.kernel}/${stdenv.hostPlatform.linux-kernel.target}";
  ROOT_FS = rootfs;

  buildFlags = "${toString buildFlags} build/live.img";

  installPhase = ''
    runHook preInstall
    mv build/live.img $out
    runHook postInstall
  '';
})
