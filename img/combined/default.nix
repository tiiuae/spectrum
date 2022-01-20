# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2021-2022 Alyssa Ross <hi@alyssa.is>
# SPDX-FileCopyrightText: 2021 Yureka <yuka@yuka.dev>

{ pkgs ? import <nixpkgs> {} }: with pkgs;

let
  inherit (builtins) storeDir;
  inherit (pkgs.lib) removePrefix;

  eosimages = import ./eosimages.nix { inherit pkgs; };

  installerPartUuid = "6e23b026-9f1e-479d-8a58-a0cda382e1ce";
  installer = import ../installer {
    inherit pkgs;

    extraConfig = {
      boot.initrd.availableKernelModules = [ "squashfs" ];

      fileSystems.${storeDir} = {
        device = "/dev/disk/by-partuuid/${installerPartUuid}";
      };
    };
  };

  rootfs = runCommand "installer.img" {
    nativeBuildInputs = [ squashfs-tools-ng ];
  } ''
    sed 's,^${storeDir}/,,' ${writeReferencesToFile installer.store} |
        tar -C ${storeDir} -c --verbatim-files-from -T - \
            --owner 0 --group 0 | tar2sqfs $out
  '';

  grub = grub2_efi;

  grubCfg = substituteAll {
    src = ./grub.cfg.in;
    linux = removePrefix storeDir installer.kernel;
    initrd = removePrefix storeDir installer.initramfs;
    inherit (installer) kernelParams;
  };

  esp = runCommand "esp.img" {
    nativeBuildInputs = [ grub libfaketime dosfstools mtools ];
    grubTargetDir = "${grub}/lib/grub/${grub.grubTarget}";
    # Definition copied from util/grub-install-common.c.
    # Last checked: GRUB 2.06
    pkglib_DATA = [
      "efiemu32.o" "efiemu64.o" "moddep.lst" "command.lst" "fs.lst" "partmap.lst"
      "parttool.lst" "video.lst" "crypto.lst" "terminal.lst" "modinfo.sh"
    ];
  } ''
    truncate -s 15M $out
    faketime "1970-01-01 00:00:00" mkfs.vfat -i 0x2178694e -n EFI $out
    mmd -i $out ::/EFI ::/EFI/BOOT \
        ::/grub ::/grub/${grub.grubTarget} ::/grub/fonts

    mcopy -i $out ${grubCfg} ::/grub/grub.cfg
    mcopy -i $out $grubTargetDir/*.mod ::/grub/${grub.grubTarget}
    for file in $pkglib_DATA; do
        path="$grubTargetDir/$file"
        ! [ -e "$path" ] || mcopy -i $out "$path" ::/grub/${grub.grubTarget}
    done
    mcopy -i $out ${grub}/share/grub/unicode.pf2 ::/grub/fonts

    grub-mkimage -o grubx64.efi -p "(hd0,gpt1)/grub" -O ${grub.grubTarget} part_gpt fat
    mcopy -i $out grubx64.efi ::/EFI/BOOT/BOOTX64.EFI

    fsck.vfat -n $out
  '';
in

runCommand "spectrum-installer" {
  nativeBuildInputs = [ grub jq util-linux systemdMinimal ];
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
  installerSize="$(blockSize ${rootfs})"
  eosimagesSize="$(blockSize ${eosimages})"

  truncate -s $(((3 * 2048 + $espSize + $installerSize + $eosimagesSize) * 512)) $out
  sfdisk $out <<EOF
  label: gpt
  size=$espSize, type=U
  size=$installerSize, type=L, uuid=${installerPartUuid}
  size=$eosimagesSize, type=56a3bbc3-aefa-43d9-a64d-7b3fd59bbc4e
  EOF

  fillPartition $out 0 ${esp}
  fillPartition $out 1 ${rootfs}
  fillPartition $out 2 ${eosimages}
''
