# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2021 Alyssa Ross <hi@alyssa.is>
# SPDX-FileCopyrightText: 2021 Yureka <yuka@yuka.dev>

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

  esp = runCommand "esp.img" {
    nativeBuildInputs = [ grub libfaketime dosfstools mtools ];
  } ''
    install -D ${grubCfg} files/grub/grub.cfg
    cp -r ${grub}/lib/grub/${grub.grubTarget} files/grub/
    cp ${grub}/share/grub/unicode.pf2 files/grub/
    grub-mkimage -o grubx64.efi -p "(hd0,gpt1)/grub" -O ${grub.grubTarget} part_gpt fat
    install -D grubx64.efi files/EFI/BOOT/BOOTX64.EFI

    img=$out
    truncate -s 15M $img
    faketime "1970-01-01 00:00:00" mkfs.vfat -i 0x2178694e -n EFI $img
    (cd files; mcopy -psvm -i $img ./* ::)
    fsck.vfat -vn $img
  '';

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
    passthru = { inherit image; };
  } ''
    truncate -s 5G "$out"
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

runCommand "spectrum-installer" {
  nativeBuildInputs = [ dosfstools grub jq kmod util-linux systemdMinimal ];
  passthru = { inherit esp installer eosimages; };
} ''
  blockSize() {
      wc -c "$1" | awk '{printf "%d\n", ($1 + 511) / 512}'
  }

  fillPartition() {
      read start size < <(sfdisk -J "$1" | jq -r --argjson index "$2" \
          '.partitiontable.partitions[$index] | "\(.start) \(.size)"')
      dd if="$3" of="$1" seek="$start" count="$size" conv=notrunc
  }

  espSize="$(blockSize ${esp})"
  installerSize="$(blockSize ${installer})"
  eosimagesSize="$(blockSize ${eosimages})"

  truncate -s $(((3 * 2048 + $espSize + $installerSize + $eosimagesSize) * 512)) $out
  sfdisk $out <<EOF
  label: gpt
  size=$espSize, type=U
  size=$installerSize, type=L, uuid=${installerUuid}
  size=$eosimagesSize, type=56a3bbc3-aefa-43d9-a64d-7b3fd59bbc4e
  EOF

  fillPartition $out 0 ${esp}
  fillPartition $out 1 ${installer}
  fillPartition $out 2 ${eosimages}
''
