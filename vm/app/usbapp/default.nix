# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2021 Alyssa Ross <hi@alyssa.is>

{ config ? import ../../../nix/eval-config.nix {}
, terminfo ? config.pkgs.foot.terminfo
}:

config.pkgs.pkgsStatic.callPackage (

{ lib, stdenvNoCC, runCommand, writeReferencesToFile, buildPackages
, s6-rc, tar2ext4
, busybox, cacert, execline, kmod, lynx, mdevd, s6, s6-linux-init, nc-vsock , usbutils, socat
}:

let
  inherit (lib) cleanSource cleanSourceWith concatMapStringsSep hasSuffix;

  packages = [
    execline kmod lynx mdevd s6 s6-linux-init s6-rc nc-vsock usbutils socat

    (busybox.override {
      extraConfig = ''
        CONFIG_DEPMOD n
        CONFIG_INSMOD n
        CONFIG_LSMOD n
        CONFIG_MODINFO n
        CONFIG_MODPROBE n
        CONFIG_RMMOD n
        CONFIG_LSUSB n
      '';
    })
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

  kernel = buildPackages.linux_latest.override {
    structuredExtraConfig = with lib.kernel; {
      VIRTIO = yes;
      VIRTIO_PCI = yes;
      VIRTIO_BLK = yes;
      VIRTIO_CONSOLE = yes;
      EXT4_FS = yes;
      DRM_BOCHS = yes;
      DRM = yes;
      AGP = yes;
      VSOCKETS = yes;
      VSOCKETS_DIAG = yes;
      VSOCKETS_LOOPBACK = yes;
      VIRTIO_VSOCKETS = module ;
      VIRTIO_VSOCKETS_COMMON = yes;
      VSOCKMON = yes;
      VHOST_VSOCK = yes;
      USBIP_CORE = module ;
      USBIP_VHCI_HCD = module;
      USBIP_HOST = module;
      USBIP_VUDC = module;
      #USBIP_DEBUG = yes;
    };
    
  };
in

stdenvNoCC.mkDerivation {
  name = "spectrum-appvm-usbapp";

  src = cleanSourceWith {
    filter = name: _type:
      name != "${toString ./.}/build" &&
      !(hasSuffix ".nix" name);
    src = cleanSource ./.;
  };

  nativeBuildInputs = [ s6-rc tar2ext4 ];

  PACKAGES_TAR = packagesTar;
  VMLINUX = "${kernel.dev}/vmlinux";

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
