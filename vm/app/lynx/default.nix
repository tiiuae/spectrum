# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2021 Alyssa Ross <hi@alyssa.is>

{ pkgs ? import <nixpkgs> {}
, terminfo ? pkgs.foot.terminfo
}:

pkgs.pkgsStatic.callPackage (

{ lib, stdenv, runCommand, writeReferencesToFile, buildPackages
, s6-rc, tar2ext4
, busybox, cacert, execline, linux, lynx, mdevd, s6, s6-linux-utils
, s6-portable-utils
}:

let
  inherit (lib) cleanSource cleanSourceWith concatMapStringsSep;

  packages = [
    busybox execline lynx mdevd s6 s6-linux-utils s6-portable-utils s6-rc
  ];

  packagesSysroot = runCommand "packages-sysroot" {
    inherit packages;
    passAsFile = [ "packages" ];
  } ''
    mkdir -p $out/usr/bin $out/usr/share
    ln -s ${concatMapStringsSep " " (p: "${p}/bin/*") packages} $out/usr/bin
    ln -s ${kernel}/lib "$out"
    ln -s ${terminfo}/share/terminfo $out/usr/share
    ln -s ${cacert}/etc/ssl $out/usr/share
  '';

  packagesTar = runCommand "packages.tar" {} ''
    cd ${packagesSysroot}
    tar -cf $out --verbatim-files-from \
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
  name = "spectrum-appvm-lynx";

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
    mv build/svc $out
  '';

  enableParallelBuilding = true;

  passthru = { inherit kernel; };

  meta = with lib; {
    license = licenses.eupl12;
    platforms = platforms.linux;
  };
}
) {}
