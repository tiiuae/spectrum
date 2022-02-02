# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2021-2022 Alyssa Ross <hi@alyssa.is>

{ pkgs ? import <nixpkgs> {} }: pkgs.pkgsStatic.callPackage (

{ lib, stdenv, runCommand, writeReferencesToFile, s6-rc, tar2ext4
, busybox, cloud-hypervisor, curl, execline, jq, mdevd, mktuntap, s6
, s6-linux-utils, s6-portable-utils, screen, util-linuxMinimal, xorg
}:

let
  inherit (lib) cleanSource cleanSourceWith concatMapStringsSep;

  start-vm = import ../start-vm { pkgs = pkgs.pkgsStatic; };

  pkgsGui = pkgs.pkgsMusl.extend (final: super: {
    systemd = final.libudev-zero;
  });

  foot = pkgsGui.foot.override { allowPgo = false; };

  packages = [
    cloud-hypervisor curl execline jq mdevd mktuntap s6 s6-linux-utils
    s6-portable-utils s6-rc screen start-vm
    pkgs.pkgsMusl.cryptsetup
    (busybox.override {
      extraConfig = ''
        CONFIG_FINDFS n
        CONFIG_INIT n
      '';
    })
  ] ++ (with pkgsGui; [ foot westonLite ]);

  kernel = pkgs.linux_latest.override {
    structuredExtraConfig = with lib.kernel; {
      VIRTIO = yes;
      VIRTIO_PCI = yes;
      VIRTIO_BLK = yes;
      EXT4_FS = yes;
      MODPROBE_PATH = freeform "/sbin/modprobe";
    };
  };

  packagesSysroot = runCommand "packages-sysroot" {
    nativeBuildInputs = [ xorg.lndir ];
  } ''
    mkdir -p $out/usr/bin
    ln -s ${concatMapStringsSep " " (p: "${p}/bin/*") packages} $out/usr/bin

    for pkg in ${lib.escapeShellArgs [ pkgsGui.mesa.drivers pkgsGui.dejavu_fonts ]}; do
        lndir -silent "$pkg" "$out/usr"
    done

    ln -s ${kernel}/lib $out/lib

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

  netvm = import ../../vm/sys/net {
    inherit pkgs;
    inherit (foot) terminfo;
  };

  appvm-catgirl = import ../../vm/app/catgirl {
    inherit pkgs;
    inherit (foot) terminfo;
  };

  appvm-lynx = import ../../vm/app/lynx {
    inherit pkgs;
    inherit (foot) terminfo;
  };

  extFs = runCommand "ext.ext4" {
    nativeBuildInputs = [ tar2ext4 s6-rc ];
  } ''
    mkdir svc

    tar -C ${netvm} -c data | tar -C svc -x
    chmod +w svc/data
    tar -C ${appvm-catgirl} -c data | tar -C svc -x
    chmod +w svc/data
    tar -C ${appvm-lynx} -c data | tar -C svc -x

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
  MODULES_ALIAS = "${kernel}/lib/modules/${kernel.modDirVersion}/modules.alias";
  MODULES_ORDER = "${kernel}/lib/modules/${kernel.modDirVersion}/modules.order";
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
