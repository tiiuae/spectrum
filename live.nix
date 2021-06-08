{ stdenv, host-rootfs, runCommand, runCommandCC
, dosfstools, jq, linux, mtools, systemd, util-linux
}:

let
  kernelTarget = stdenv.hostPlatform.linux-kernel.target;

  uki = runCommandCC "spectrum-uki" {
    passAsFile = [ "cmdline" "osrel" ];
    cmdline = "ro console=ttyS0";
    osrel = ''
      PRETTY_NAME="Spectrum"
      VERSION_ID=0.1
    '';
  } ''
    objcopy --add-section .osrel=$osrelPath --change-section-vma .osrel=0x20000 \
            --add-section .cmdline=$cmdlinePath --change-section-vma .cmdline=0x30000 \
            --add-section .linux=${linux}/${kernelTarget} --change-section-vma .linux=0x40000 \
            ${systemd}/lib/systemd/boot/efi/linuxx64.efi.stub $out
  '';

  efi = runCommand "spectrum-efi" {
    nativeBuildInputs = [ dosfstools mtools ];
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
