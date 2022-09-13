# SPDX-FileCopyrightText: 2021-2022 Alyssa Ross <hi@alyssa.is>
# SPDX-License-Identifier: MIT

{ pkgs ? import <nixpkgs> {}
, rootfs ? import ../rootfs { inherit pkgs; }
}:

pkgs.callPackage (
{ lib, stdenvNoCC, makeModulesClosure, runCommand, writeReferencesToFile
, pkgsStatic, busybox, cpio, cryptsetup, lvm2, microcodeAmd, microcodeIntel
}:

let
  inherit (lib) cleanSource cleanSourceWith concatMapStringsSep hasSuffix;

  linux = rootfs.kernel;

  modules = makeModulesClosure {
    inherit (rootfs) firmware kernel;
    rootModules = [ "dm-verity" "loop" ];
  };

  packages = [
    pkgsStatic.execline pkgsStatic.kmod pkgsStatic.mdevd

    (pkgsStatic.cryptsetup.override {
      programs = {
        cryptsetup = false;
        cryptsetup-reencrypt = false;
        integritysetup = false;
      };
    })

    (busybox.override {
      enableStatic = true;
      extraConfig = ''
        CONFIG_DEPMOD n
        CONFIG_FINDFS n
        CONFIG_INSMOD n
        CONFIG_LSMOD n
        CONFIG_MODINFO n
        CONFIG_MODPROBE n
        CONFIG_RMMOD n
      '';
    })
  ];

  packagesSysroot = runCommand "packages-sysroot" {} ''
    mkdir -p $out/bin
    ln -s ${concatMapStringsSep " " (p: "${p}/bin/*") packages} $out/bin
    cp -R ${modules}/lib $out
    ln -s /bin $out/sbin

    # TODO: this is a hack and we should just build the util-linux
    # programs we want.
    # https://lore.kernel.org/util-linux/87zgrl6ufb.fsf@alyssa.is/
    cp ${pkgsStatic.util-linuxMinimal}/bin/{findfs,lsblk} $out/bin
  '';

  microcode = if stdenvNoCC.hostPlatform.isx86_64 then
    runCommand "microcode.cpio" {
      nativeBuildInputs = [ cpio ];
    } ''
      cpio -id < ${microcodeAmd}/amd-ucode.img
      cpio -id < ${microcodeIntel}/intel-ucode.img
      find kernel | cpio -oH newc -R +0:+0 --reproducible > $out
    ''
  else null;

  packagesCpio = runCommand "packages.cpio" {
    nativeBuildInputs = [ cpio ];
    storePaths = writeReferencesToFile packagesSysroot;
  } ''
    cd ${packagesSysroot}
    (printf "/nix\n/nix/store\n" && find . $(< $storePaths)) |
        cpio -o -H newc -R +0:+0 --reproducible > $out
  '';
in

stdenvNoCC.mkDerivation {
  name = "initramfs";

  src = cleanSourceWith {
    filter = name: _type:
      name != "${toString ./.}/build" &&
      !(hasSuffix ".nix" name);
    src = cleanSource ./.;
  };

  MICROCODE = microcode;
  PACKAGES_CPIO = packagesCpio;

  nativeBuildInputs = [ cpio ];

  installPhase = ''
    runHook preInstall
    cp build/initramfs $out
    runHook postInstall
  '';

  enableParallelBuilding = true;
}
) {}
