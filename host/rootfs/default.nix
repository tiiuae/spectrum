# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2021-2022 Alyssa Ross <hi@alyssa.is>

{ pkgs ? import <nixpkgs> {} }: pkgs.pkgsStatic.callPackage (

{ lib, stdenv, nixos, runCommand, writeReferencesToFile, s6-rc, tar2ext4
, busybox, cloud-hypervisor, cryptsetup, execline, jq, kmod
, mdevd, s6, s6-linux-init, socat, util-linuxMinimal, xorg
}:

let
  inherit (lib) cleanSource cleanSourceWith concatMapStringsSep hasSuffix;
  inherit (nixosAllHardware.config.hardware) firmware;

  start-vm = import ../start-vm { pkgs = pkgs.pkgsStatic; };

  pkgsGui = pkgs.pkgsMusl.extend (final: super: {
    systemd = final.libudev-zero;
  });

  foot = pkgsGui.foot.override { allowPgo = false; };

  packages = [
    cloud-hypervisor execline jq kmod mdevd s6 s6-linux-init s6-rc socat
    start-vm

    (cryptsetup.override {
      programs = {
        cryptsetup = false;
        cryptsetup-reencrypt = false;
        integritysetup = false;
      };
    })

    (busybox.override {
      extraConfig = ''
        CONFIG_DEPMOD n
        CONFIG_FINDFS n
        CONFIG_INIT n
        CONFIG_INSMOD n
        CONFIG_LSMOD n
        CONFIG_MODINFO n
        CONFIG_MODPROBE n
        CONFIG_RMMOD n
      '';
    })
  ] ++ (with pkgsGui; [ foot westonLite ]);

  nixosAllHardware = nixos ({ modulesPath, ... }: {
    imports = [ (modulesPath + "/profiles/all-hardware.nix") ];
  });

  kernelPackages = pkgs.linuxPackagesFor (pkgs.linuxKernel.manualConfig {
    inherit (pkgs) stdenv lib;

    version = "5.15.53-hardened1";

    src = pkgs.fetchurl {
      url = "https://github.com/anthraxx/linux-hardened/archive/refs/tags/5.15.53-hardened1.tar.gz";
      sha256 = "3157a4cadd167e0892cd4257f778dbe8d00b7ff6300c9c2dafaabb13852fa2fc";
    };

    configfile = ./generated_x86_qemu-nixos_host_release_defconfig;
    allowImportFromDerivation = true;
  });

  kernel = kernelPackages.kernel;

  packagesSysroot = runCommand "packages-sysroot" {
    nativeBuildInputs = [ xorg.lndir ];
  } ''
    mkdir -p $out/lib $out/usr/bin
    ln -s ${concatMapStringsSep " " (p: "${p}/bin/*") packages} $out/usr/bin

    for pkg in ${lib.escapeShellArgs [ pkgsGui.mesa.drivers pkgsGui.dejavu_fonts ]}; do
        lndir -silent "$pkg" "$out/usr"
    done

    ln -s ${kernel}/lib/modules ${firmware}/lib/firmware $out/lib

    # TODO: this is a hack and we should just build the util-linux
    # programs we want.
    # https://lore.kernel.org/util-linux/87zgrl6ufb.fsf@alyssa.is/
    ln -s ${util-linuxMinimal}/bin/{findfs,lsblk} $out/usr/bin
  '';

  packagesTar = runCommand "packages.tar" {} ''
    cd ${packagesSysroot}
    tar -cf $out --sort=name --mtime=@0 --verbatim-files-from \
        -T ${writeReferencesToFile packagesSysroot} .
  '';
in

stdenv.mkDerivation {
  name = "spectrum-rootfs";

  src = cleanSourceWith {
    filter = name: _type:
      name != "${toString ./.}/build" && !(hasSuffix ".nix" name);
    src = cleanSource ./.;
  };

  nativeBuildInputs = [ s6-rc tar2ext4 ];

  MODULES_ALIAS = "${kernel}/lib/modules/${kernel.modDirVersion}/modules.alias";
  MODULES_ORDER = "${kernel}/lib/modules/${kernel.modDirVersion}/modules.order";
  PACKAGES_TAR = packagesTar;

  installPhase = ''
    cp build/rootfs.ext4 $out
  '';

  enableParallelBuilding = true;

  passthru = { inherit firmware kernel nixosAllHardware; };

  meta = with lib; {
    license = licenses.eupl12;
    platforms = platforms.linux;
  };
}
) {}
