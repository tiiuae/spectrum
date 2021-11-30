{ stdenv, host-rootfs, extfs, runCommand, runCommandCC, writeReferencesToFile
, pkgsStatic
, busybox, cpio, cryptsetup, dosfstools, jq, linux, lvm2, mtools, systemd
, util-linux
}:

let
  cryptsetup' = cryptsetup;
in
let
  cryptsetup = cryptsetup'.override { lvm2 = lvm2.override { udev = null; }; };

  kernelTarget = stdenv.hostPlatform.linux-kernel.target;

  initramfs = runCommand "spectrum-initramfs" {
    nativeBuildInputs = [ cpio ];
  } ''
    installPkg() {
        cp -r $1 root/nix/store
        ln -sf $1/bin/* root/bin
    }

    mkdir -p root/{bin,dev,etc,mnt,nix/store,proc,sys,tmp}
    xargs cp -rt root/nix/store < ${writeReferencesToFile cryptsetup}
    ln -s ${cryptsetup}/bin/* root/bin
    installPkg ${busybox.override { enableStatic = true; }}

    installPkg ${pkgsStatic.mdevd}
    installPkg ${pkgsStatic.execline}

    cp -fv ${pkgsStatic.coreutils}/bin/date root/bin

    cp -f ${pkgsStatic.utillinux.override { systemd = null; }}/bin/{blkid,findfs,lsblk} root/bin
    ln -s /bin root/sbin
    install ${etc/init} root/init
    grep -m 1 '^Root hash' ${verity.table} | awk '{print $3}' > root/etc/roothash
    cp ${etc/mdev.conf} root/etc/mdev.conf
    cp -R ${linux}/lib root
    cd root
    find * -print0 | xargs -0r touch -h -d '@1'
    find * -print0 | sort -z | cpio -o -H newc -R +0:+0 --reproducible --null | gzip -9n > $out
  '';

  uki = runCommandCC "spectrum-uki" {
    passAsFile = [ "cmdline" ];
    cmdline = "ro console=ttyS0";
    inherit initramfs;
  } ''
    objcopy --add-section .osrel=${etc/os-release} --change-section-vma .osrel=0x20000 \
            --add-section .cmdline=$cmdlinePath --change-section-vma .cmdline=0x30000 \
            --add-section .linux=${linux}/${kernelTarget} --change-section-vma .linux=0x40000 \
            --add-section .initrd=$initramfs --change-section-vma .initrd=0x3000000 \
            ${systemd}/lib/systemd/boot/efi/linuxx64.efi.stub $out
  '';

  efi = runCommand "spectrum-efi" {
    nativeBuildInputs = [ dosfstools mtools ];
    passthru = { inherit uki; };
  } ''
    truncate -s ${toString (100 * 1024 * 1024)} $out
    mkfs.vfat $out
    mmd -i $out ::/EFI ::/EFI/BOOT
    mcopy -i $out ${uki} ::/EFI/BOOT/BOOTX64.EFI
  '';

  verity = runCommand "spectrum-verity" {
    nativeBuildInputs = [ cryptsetup ];
    outputs = [ "out" "table" ];
  } ''
    veritysetup format ${host-rootfs} $out > $table
  '';
in

runCommand "spectrum-live" {
  nativeBuildInputs = [ jq util-linux ];
  passthru = {
    inherit efi verity;
    rootfs = host-rootfs;
  };
} ''
  blockSize() {
      wc -c "$1" | awk '{printf "%d\n", ($1 + 511) / 512}'
  }

  fillPartition() {
      read start size < <(sfdisk -J "$1" | jq -r --argjson index "$2" \
          '.partitiontable.partitions[$index] | "\(.start) \(.size)"')
      dd if="$3" of="$1" seek="$start" count="$size" conv=notrunc
  }

  efiSize="$(blockSize ${efi})"
  veritySize="$(blockSize ${verity})"
  rootfsSize="$(blockSize ${host-rootfs})"
  extSize="$(blockSize ${extfs})"

  truncate -s $(((4 * 2048 + $efiSize + $veritySize + $rootfsSize + $extSize) * 512)) $out
  sfdisk $out <<EOF
  label: gpt
  - $efiSize    U                                    -
  - $veritySize 2c7357ed-ebd2-46d9-aec1-23d437ec2bf5 -
  - $rootfsSize 4f68bce3-e8cd-4db1-96e7-fbcaf984b709 -
  - $extSize    9293e1ff-cee4-4658-88be-898ec863944f -
  EOF

  fillPartition $out 0 ${efi}
  fillPartition $out 1 ${verity}
  fillPartition $out 2 ${host-rootfs}
  fillPartition $out 3 ${extfs}
''
