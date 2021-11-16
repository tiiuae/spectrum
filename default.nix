# SPDX-License-Identifier: EUPL-1.2
# SPDX-FileCopyrightText: 2021 Alyssa Ross <hi@alyssa.is>

{ pkgs ? import <nixpkgs> {} }: pkgs.pkgsStatic.callPackage (

{ lib, stdenv, runCommand, writeReferencesToFile, s6-rc, tar2ext4
, busybox, cloud-hypervisor, curl, execline, jq, mdevd, mktuntap, s6
, s6-linux-utils, s6-portable-utils, screen, util-linux
}:

let
  inherit (lib) cleanSource cleanSourceWith concatMapStringsSep;

  pkgsGui = pkgs.pkgsMusl.extend (final: super: {
    systemd = final.libudev-zero;
  });

  packages = [
    cloud-hypervisor curl execline jq mdevd mktuntap s6 s6-linux-utils
    s6-portable-utils s6-rc screen pkgsGui.westonLite
    (busybox.override {
      extraConfig = ''
        CONFIG_INIT n
      '';
    })
  ];

  kernel = pkgs.linux.override {
    structuredExtraConfig = with lib.kernel; {
      VIRTIO = yes;
      VIRTIO_PCI = yes;
      VIRTIO_BLK = yes;
      EXT4_FS = yes;
    };
  };

  packagesSysroot = runCommand "packages-sysroot" {} ''
    mkdir -p $out/usr/bin
    ln -s ${concatMapStringsSep " " (p: "${p}/bin/*") packages} $out/usr/bin
    ln -s ${pkgsGui.mesa.drivers}/* $out/usr
    ln -s ${kernel}/lib $out/lib

    # TODO: this is a hack and we should just build the util-linux
    # programs we want.
    # https://lore.kernel.org/util-linux/87zgrl6ufb.fsf@alyssa.is/
    ln -s ${util-linux.override { systemd = null; }}/bin/lsblk $out/usr/bin
  '';

  packagesTar = runCommand "packages.tar" {} ''
    cd ${packagesSysroot}
    tar -cf $out --verbatim-files-from \
        -T ${writeReferencesToFile packagesSysroot} .
  '';

  netvm = import ../spectrum-netvm { inherit pkgs; };
  appvm-lynx = import ../spectrum-appvm-lynx { inherit pkgs; };

  extFs = runCommand "ext.ext4" {
    nativeBuildInputs = [ tar2ext4 s6-rc ];
  } ''
    mkdir src svc
    tar -C ${netvm} -c . | tar -C src -x
    chmod +w src
    tar -C ${appvm-lynx} -c . | tar -C src -x
    chmod +w src
    mkdir src/default
    echo bundle > src/default/type
    echo appvm-lynx > src/default/contents
    s6-rc-compile svc/s6-rc src
    tar -cf ext.tar svc
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

  passthru = { inherit kernel; };

  meta = with lib; {
    license = licenses.eupl12;
    platforms = platforms.linux;
  };
}
) {}
