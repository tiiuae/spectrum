# SPDX-License-Identifier: EUPL-1.2
# SPDX-FileCopyrightText: 2021 Alyssa Ross <hi@alyssa.is>

{ pkgs ? import <nixpkgs> {} }: pkgs.pkgsStatic.callPackage (

{ lib, stdenv, runCommand, writeReferencesToFile, buildPackages
, s6-rc, tar2ext4, xorg
, busybox, execline, linux, mdevd, s6, s6-linux-utils, s6-portable-utils
}:

let
  inherit (lib) cleanSource cleanSourceWith concatMapStringsSep;

  packages = [
    busybox execline mdevd s6 s6-linux-utils s6-portable-utils s6-rc
  ];

  packagesSysroot = runCommand "packages-sysroot" {
    inherit packages;
    nativeBuildInputs = [ xorg.lndir ];
    passAsFile = [ "packages" ];
  } ''
    mkdir -p "$out/usr/bin" "$out/usr/share"
    for pkg in $(< "$packagesPath"); do
        for dir in bin share; do
            if [ -e "$pkg/$dir" ]; then
                lndir -silent "$pkg/$dir" "$out/usr/$dir"
            fi
        done
    done
    ln -s "${kernel}/lib" "$out"
  '';

  packagesTar = runCommand "packages.tar" {} ''
    cd ${packagesSysroot}
    tar -cvf $out --verbatim-files-from \
        -T ${writeReferencesToFile packagesSysroot} .
  '';

  kernel = buildPackages.linux.override {
    structuredExtraConfig = with lib.kernel; {
      VIRTIO = yes;
      VIRTIO_PCI = yes;
      VIRTIO_BLK = yes;
      VIRTIO_CONSOLE = yes;
      EXT4_FS = yes;
      DRM_BOCHS = yes;
      DRM = yes;
      AGP = yes;
    };
  };
in

stdenv.mkDerivation {
  name = "spectrum-netvm";

  src = cleanSourceWith {
    filter = name: _type: name != "${toString ./.}/build";
    src = cleanSource ./.;
  };

  nativeBuildInputs = [ s6-rc tar2ext4 ];

  PACKAGES_TAR = packagesTar;
  VMLINUX = "${kernel.dev}/vmlinux";

  postPatch = ''
    mkdir $NIX_BUILD_TOP/empty
    substituteInPlace Makefile --replace /var/empty $NIX_BUILD_TOP/empty
  '';

  installPhase = ''
    mv build/s6-rc $out
  '';

  enableParallelBuilding = true;

  passthru = { inherit kernel; };

  meta = with lib; {
    license = licenses.eupl12;
    platforms = platforms.linux;
  };
}
) {}
