# SPDX-FileCopyrightText: 2022 Unikie

{ pkgs ? import <nixpkgs> {
    crossSystem = {
      config = "aarch64-unknown-linux-musl";
    };
  }}:

let
  uboot = pkgs.ubootIMX8QXP;
  spectrum = import ../live { inherit pkgs; };
  kernel = spectrum.rootfs.kernel;
  kvms = pkgs.kvms;

  kvers = "${kernel.version}";
in

with pkgs;

stdenvNoCC.mkDerivation {
  pname = "spectrum-live-imx8qxp.img";
  version = "0.1";

  nativeBuildInputs = [
    pkgsBuildHost.util-linux
    pkgsBuildHost.jq
    pkgsBuildHost.mtools
  ];

  buildCommand = ''
    install -m 0644 ${spectrum} spectrum-live-imx8qxp.img
    dd if=${uboot}/flash.bin of=spectrum-live-imx8qxp.img bs=1k seek=32 conv=notrunc
    IMG=spectrum-live-imx8qxp.img
    ESP_OFFSET=$(sfdisk --json $IMG | jq -r '
      # Partition type GUID identifying EFI System Partitions
      def ESP_GUID: "C12A7328-F81F-11D2-BA4B-00A0C93EC93B";
      .partitiontable |
      .sectorsize * (.partitions[] | select(.type == ESP_GUID) | .start)
    ')
    mcopy -no -i spectrum-live-imx8qxp.img@@$ESP_OFFSET ${kernel}/dtbs/freescale/imx8qxp-mek.dtb ::/
    mcopy -no -i spectrum-live-imx8qxp.img@@$ESP_OFFSET ${kvms.src}/platform/nxp/imx8qxp/${kvers}/bl1.bin ::/
    mv spectrum-live-imx8qxp.img $out
  '';
}
