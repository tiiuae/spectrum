# SPDX-FileCopyrightText: 2022 Unikie

{ pkgs ? import <nixpkgs> {
    crossSystem = {
      config = "aarch64-unknown-linux-musl";
    };
  }}:

let
  uboot = pkgs.ubootIMX8QM;
  spectrum = import ../live { inherit pkgs; };
  kernel = spectrum.rootfs.kernel;
in

with pkgs;

stdenvNoCC.mkDerivation {
  pname = "spectrum-live-imx8qm.img";
  version = "0.1";

  nativeBuildInputs = [
    pkgsBuildHost.util-linux
    pkgsBuildHost.jq
    pkgsBuildHost.mtools
  ];

  buildCommand = ''
    install -m 0644 ${spectrum} spectrum-live-imx8qm.img
    dd if=${uboot}/flash.bin of=spectrum-live-imx8qm.img bs=1k seek=32 conv=notrunc
    IMG=spectrum-live-imx8qm.img
    ESP_OFFSET=$(sfdisk --json $IMG | jq -r '
      # Partition type GUID identifying EFI System Partitions
      def ESP_GUID: "C12A7328-F81F-11D2-BA4B-00A0C93EC93B";
      .partitiontable |
      .sectorsize * (.partitions[] | select(.type == ESP_GUID) | .start)
    ')
    mcopy -no -i spectrum-live-imx8qm.img@@$ESP_OFFSET ${kernel}/dtbs/freescale/imx8qm-mek-hdmi.dtb ::/
    mcopy -no -i spectrum-live-imx8qm.img@@$ESP_OFFSET ${pkgs.imx-firmware}/hdmitxfw.bin ::/
    mv spectrum-live-imx8qm.img $out
  '';
}
