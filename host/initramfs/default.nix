{ pkgs ? import <nixpkgs> {}
, rootfs ? import ../rootfs { inherit pkgs; }
}:

pkgs.callPackage (
{ lib, stdenv, runCommand, writeReferencesToFile, pkgsStatic
, busybox, cpio, cryptsetup, lvm2
}:

let
  cryptsetup' = cryptsetup;
in
let
  inherit (lib) cleanSource cleanSourceWith concatMapStringsSep;

  cryptsetup = cryptsetup'.override { lvm2 = lvm2.override { udev = null; }; };
  linux = rootfs.kernel;

  packages = [
    cryptsetup pkgsStatic.mdevd pkgsStatic.execline

    (busybox.override {
      enableStatic = true;
      extraConfig = ''
        CONFIG_FINDFS n
      '';
    })
  ];

  packagesSysroot = runCommand "packages-sysroot" {} ''
    mkdir -p $out/bin
    ln -s ${concatMapStringsSep " " (p: "${p}/bin/*") packages} $out/bin
    cp -R ${linux}/lib $out
    ln -s /bin $out/sbin

    # TODO: this is a hack and we should just build the util-linux
    # programs we want.
    # https://lore.kernel.org/util-linux/87zgrl6ufb.fsf@alyssa.is/
    cp ${pkgsStatic.util-linux.override { systemd = null; }}/bin/{findfs,lsblk} $out/bin
  '';

  packagesCpio = runCommand "packages.cpio" {
    nativeBuildInputs = [ cpio ];
    storePaths = writeReferencesToFile packagesSysroot;
  } ''
    cd ${packagesSysroot}
    (printf "/nix\n/nix/store\n" && find . $(< $storePaths)) |
        cpio -o -H newc -R +0:+0 --reproducible > $out
  '';
in

stdenv.mkDerivation {
  name = "initramfs";

  src = cleanSourceWith {
    filter = name: _type: name != "${toString ./.}/build";
    src = cleanSource ./.;
  };

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
