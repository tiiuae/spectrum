{ pkgs ? import <nixpkgs> {} }: with pkgs;

let
  image = import ../../spectrum-initramfs/live.nix { inherit pkgs; };

  emptyDisk = runCommand "empty.img" {} ''
    truncate -s 10G $out
  '';

  eosimages = vmTools.runInLinuxVM (runCommand "eosimages.img" {
    nativeBuildInputs = [ exfatprogs kmod util-linux ];
  } ''
    truncate -s 3G "$out"
    sfdisk "$out" <<EOF
    label: gpt
    - - L -
    EOF
    modprobe loop
    loop="$(losetup -P --show -f "$out")"
    mkfs.exfat -L eosimages "$loop"p1
    mkdir /mnt
    mount "$loop"p1 /mnt
    name=Spectrum-0.0-x86_64-generic.0.Live.img.gz
    gzip < ${image} > /mnt/$name
    sha256sum /mnt/$name > /mnt/$name.sha256
  '');
in

(import (path + "/nixos") {
  configuration = {
    imports = [ ../configuration.nix ];

    virtualisation.memorySize = 2048;
    virtualisation.useBootLoader = true;
    virtualisation.useEFIBoot = true;
    virtualisation.qemu.options = [ "-snapshot" ];
    virtualisation.qemu.drives = [
      { file = "${emptyDisk}"; }
      { file = "${eosimages}"; driveExtraOpts = { readonly = "on"; }; }
    ];
  };
}).vm
