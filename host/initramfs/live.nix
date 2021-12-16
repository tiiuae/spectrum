{ pkgs ? import <nixpkgs> {} }: pkgs.callPackage (

{ stdenv, runCommand, runCommandCC, callPackage, pkgsStatic
, cryptsetup, dosfstools, jq, mtools, systemd, util-linux
}:

let
  initramfs = (import ./. { inherit pkgs; }).override { linux = kernel; };
  host-rootfs = import ../rootfs { inherit pkgs; };
  extfs = pkgsStatic.callPackage ./extfs.nix { inherit pkgs; };

  inherit (host-rootfs) kernel;
  kernelTarget = stdenv.hostPlatform.linux-kernel.target;

  uki = runCommandCC "spectrum-uki" {
    passAsFile = [ "cmdline" ];
    cmdline = "ro console=ttyS0";
    inherit initramfs;
  } ''
    roothash="$(awk -F ':[[:blank:]]*' '$1 == "Root hash" {print $2; exit}' ${verity.table})"
    echo "ro console=ttyS0 roothash=$roothash" > cmdline
    objcopy --add-section .osrel=${etc/os-release} --change-section-vma .osrel=0x20000 \
            --add-section .cmdline=cmdline --change-section-vma .cmdline=0x30000 \
            --add-section .linux=${kernel}/${kernelTarget} --change-section-vma .linux=0x40000 \
            --add-section .initrd=$initramfs --change-section-vma .initrd=0x3000000 \
            ${systemd}/lib/systemd/boot/efi/linuxx64.efi.stub $out
  '';

  efi = runCommand "spectrum-efi" {
    nativeBuildInputs = [ dosfstools mtools ];
    passthru = { inherit uki; };
  } ''
    truncate -s ${toString (150 * 1024 * 1024)} $out
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

  formatUuid() {
      printf "%s\n" "''${1:0:8}-''${1:8:4}-''${1:12:4}-''${1:16:4}-''${1:20}"
  }

  roothash="$(awk -F ':[[:blank:]]*' '$1 == "Root hash" {print $2; exit}' ${verity.table})"

  efiSize="$(blockSize ${efi})"
  veritySize="$(blockSize ${verity})"
  rootfsSize="$(blockSize ${host-rootfs})"
  extSize="$(blockSize ${extfs})"

  truncate -s $(((4 * 2048 + $efiSize + $veritySize + $rootfsSize + $extSize) * 512)) $out
  sfdisk $out <<EOF
  label: gpt
  size=$efiSize,    type=c12a7328-f81f-11d2-ba4b-00a0c93ec93b
  size=$veritySize, type=2c7357ed-ebd2-46d9-aec1-23d437ec2bf5, uuid=$(formatUuid "$(printf "%s" "$roothash" | tail -c 32)")
  size=$rootfsSize, type=4f68bce3-e8cd-4db1-96e7-fbcaf984b709, uuid=$(formatUuid "$(printf "%s" "$roothash" | head -c 32)")
  size=$extSize,    type=9293e1ff-cee4-4658-88be-898ec863944f
  EOF

  fillPartition $out 0 ${efi}
  fillPartition $out 1 ${verity}
  fillPartition $out 2 ${host-rootfs}
  fillPartition $out 3 ${extfs}
''
) {}
