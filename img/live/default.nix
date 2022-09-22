# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2021-2022 Alyssa Ross <hi@alyssa.is>

{ config ? import ../../nix/eval-config.nix {} }:

let
  inherit (config) pkgs;
  inherit (pkgs.lib) cleanSource cleanSourceWith hasSuffix;

  extfs = pkgs.pkgsStatic.callPackage ../../host/initramfs/extfs.nix {
    inherit config;
  };
  rootfs = import ../../host/rootfs { inherit config; };
  scripts = import ../../scripts { inherit config; };
  initramfs = import ../../host/initramfs { inherit config rootfs; };
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
  SYSTEMD_BOOT_EFI = "${systemd}/lib/systemd/boot/efi/systemd-bootx64.efi";

  buildFlags = [ "build/live.img" ];
  makeFlags = [ "SCRIPTS=${scripts}" ];

  installPhase = ''
    runHook preInstall
    mv build/live.img $out
    runHook postInstall
  '';

  enableParallelBuilding = true;

  passthru = { inherit rootfs; };
}
