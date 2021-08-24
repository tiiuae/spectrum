# SPDX-License-Identifier: EUPL-1.2
# SPDX-FileCopyrightText: 2021 Alyssa Ross <hi@alyssa.is>

{ pkgs ? import <nixpkgs> {} }: pkgs.pkgsStatic.callPackage (

{ lib, stdenv, runCommand, writeReferencesToFile, s6-rc, tar2ext4
, busybox, execline, mdevd, s6, s6-linux-utils, s6-portable-utils, tmux
}:

let
  inherit (lib) cleanSource cleanSourceWith concatMapStringsSep;

  packages = [
    busybox execline mdevd s6 s6-linux-utils s6-portable-utils s6-rc tmux
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
in

stdenv.mkDerivation {
  name = "spectrum-rootfs";

  src = cleanSourceWith {
    filter = name: _type: name != "${toString ./.}/build";
    src = cleanSource ./.;
  };

  nativeBuildInputs = [ s6-rc tar2ext4 ];

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
