{ stdenv, host-rootfs, runCommand, runCommandCC
, busybox, cpio, dosfstools, jq, linux, mtools, systemd, util-linux
}:

let
  kernelTarget = stdenv.hostPlatform.linux-kernel.target;

  initramfs = runCommand "spectrum-initramfs" {
    nativeBuildInputs = [ cpio ];
    passAsFile = [ "init" ];
    init = ''
      #!/bin/sh -eux
      mount -t devtmpfs none /dev
      mount -t proc none /proc
      mount -t sysfs none /sys
      echo hello world
      exec sh -li
    '';
  } ''
    mkdir -p root
    cp -R ${busybox.override { enableStatic = true; }}/bin root
    install $initPath root/init
    cp -R ${linux}/lib root
    cd root
    find * -print0 | xargs -0r touch -h -d '@1'
    find * -print0 | sort -z | cpio -o -H newc -R +0:+0 --reproducible --null | gzip -9n > $out
  '';

  uki = runCommandCC "spectrum-uki" {
    passAsFile = [ "cmdline" "osrel" ];
    cmdline = "ro console=ttyS0";
    osrel = ''
      PRETTY_NAME="Spectrum"
      VERSION_ID=0.1
    '';
    inherit initramfs;
  } ''
    objcopy --add-section .osrel=$osrelPath --change-section-vma .osrel=0x20000 \
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
in

runCommand "spectrum-live" {
  nativeBuildInputs = [ jq util-linux ];
  passthru = {
    inherit efi;
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

  squashfsSize="$(blockSize ${host-rootfs.squashfs})"
  efiSize="$(blockSize ${efi})"

  truncate -s $(((3 * 2048 + $squashfsSize + $efiSize) * 512)) $out
  sfdisk $out <<EOF
  label: gpt
  - $efiSize      U -
  - $squashfsSize L -
  EOF

  fillPartition $out 0 ${efi}
  fillPartition $out 1 ${host-rootfs.squashfs}
''
