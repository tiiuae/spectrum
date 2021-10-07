# SPDX-License-Identifier: EUPL-1.2
# SPDX-FileCopyrightText: 2021 Alyssa Ross <hi@alyssa.is>

{ pkgs ? import <nixpkgs> {} }: pkgs.pkgsStatic.callPackage (

{ lib, stdenv, runCommand, writeReferencesToFile, s6-rc, tar2ext4
, busybox, execline, mdevd, s6, s6-linux-utils, s6-portable-utils, screen
}:

let
  inherit (lib) cleanSource cleanSourceWith concatMapStringsSep;

  packages = [
    busybox execline mdevd s6 s6-linux-utils s6-portable-utils s6-rc screen
  ];

  packagesBin = runCommand "packages-bin" {} ''
    mkdir -p $out/bin
    ln -s ${concatMapStringsSep " " (p: "${p}/bin/*") packages} $out/bin
  '';

  packagesTar = runCommand "packages.tar" {} ''
    cd ${packagesBin}
    tar -cvf $out --verbatim-files-from \
        -T ${writeReferencesToFile packagesBin} bin
  '';

  extTar = runCommand "ext.tar" {
    nativeBuildInputs = [ s6-rc ];
  } ''
    mkdir -p s6-rc/default $out/svc
    echo s6-echo hello world > s6-rc/default/up
    echo oneshot > s6-rc/default/type
    s6-rc-compile $out/svc/s6-rc s6-rc
  '';

  extFs = runCommand "ext.ext4" {
    nativeBuildInputs = [ tar2ext4 ];
  } ''
    tar -C ${extTar} -cf ext.tar .
    tar2ext4 -i ext.tar -o $out
  '';
in

stdenv.mkDerivation {
  name = "spectrum-rootfs";

  src = cleanSourceWith {
    filter = name: _type: name != "${toString ./.}/build";
    src = cleanSource ./.;
  };

  nativeBuildInputs = [ s6-rc tar2ext4 ];

  EXT_FS = extFs;
  PACKAGES_TAR = packagesTar;

  postPatch = ''
    mkdir $NIX_BUILD_TOP/empty
    substituteInPlace Makefile --replace /var/empty $NIX_BUILD_TOP/empty
  '';

  installPhase = ''
    cp build/rootfs.ext4 $out
  '';

  enableParallelBuilding = true;

  meta = with lib; {
    license = licenses.eupl12;
    platforms = platforms.linux;
  };
}
) {}
