# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2021 Alyssa Ross <hi@alyssa.is>

{ pkgs ? import <nixpkgs> {} }: with pkgs;

let
  inherit (builtins) head match storeDir;
  inherit (pkgs.lib) removePrefix;
  inherit (nixos ./configuration.nix) config;

  image = import ../host/initramfs/live.nix { inherit pkgs; };

  grub = grub2_efi;

  grubCfg = substituteAll {
    src = ./grub.cfg.in;
    linux = removePrefix storeDir "${config.boot.kernelPackages.kernel}/${config.system.boot.loader.kernelFile}";
    initrd = removePrefix storeDir "${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile}";
    kernelParams = toString ([
      "init=${config.system.build.toplevel}/init"
    ] ++ config.boot.kernelParams);
  };

  installer = runCommand "installer.img" {
    nativeBuildInputs = [ squashfs-tools-ng ];
  } ''
    sed 's,^${storeDir}/,,' ${writeReferencesToFile config.system.build.toplevel} |
        tar -C ${storeDir} -c --verbatim-files-from -T - \
            --owner 0 --group 0 | tar2sqfs $out
  '';

  storeDev = config.fileSystems."/nix/store".device;
  installerUuid = head (match "/dev/disk/by-partuuid/(.*)" storeDev);

  eosimages = vmTools.runInLinuxVM (runCommand "eosimages.img" {
    nativeBuildInputs = [ exfatprogs kmod util-linux ];
  } ''
    truncate -s 4G "$out"
    mkfs.exfat -L eosimages "$out"
    mkdir /mnt
    modprobe loop
    mount "$out" /mnt
    name=Spectrum-0.0-x86_64-generic.0.Live.img
    cp ${image} /mnt/$name
    sha256sum /mnt/$name > /mnt/$name.sha256
    umount /mnt
  '');
in

vmTools.runInLinuxVM (runCommand "spectrum-installer" {
  nativeBuildInputs = [ dosfstools grub jq kmod util-linux systemdMinimal ];
} ''
  blockSize() {
      wc -c "$1" | awk '{printf "%d\n", ($1 + 511) / 512}'
  }

  fillPartition() {
      read start size < <(sfdisk -J "$1" | jq -r --argjson index "$2" \
          '.partitiontable.partitions[$index] | "\(.start) \(.size)"')
      dd if="$3" of="$1" seek="$start" count="$size" conv=notrunc
  }

  efiSize=40000
  installerSize="$(blockSize ${installer})"
  eosimagesSize="$(blockSize ${eosimages})"

  truncate -s $(((3 * 2048 + $efiSize + $installerSize + $eosimagesSize) * 512)) $out
  sfdisk $out <<EOF
  label: gpt
  size=$efiSize, type=U
  size=$installerSize, type=L, uuid=${installerUuid}
  size=$eosimagesSize, type=56a3bbc3-aefa-43d9-a64d-7b3fd59bbc4e
  EOF

  fillPartition $out 1 ${installer}
  fillPartition $out 2 ${eosimages}

  modprobe loop
  loop="$(losetup -P --show -f $out)"
  mkfs.vfat "$loop"p1
  mkdir /mnt
  mount "$loop"p1 /mnt
  grub-install --target ${grub.grubTarget} --removable \
      --boot-directory /mnt --efi-directory /mnt "$loop"
  cp ${grubCfg} /mnt/grub/grub.cfg
  umount /mnt
'')
