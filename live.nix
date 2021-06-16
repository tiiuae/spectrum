{ stdenv, host-rootfs, runCommand, runCommandCC
, busybox, cpio, dosfstools, jq, linux, mtools, systemd, pkgsStatic, util-linux
}:

let
  kernelTarget = stdenv.hostPlatform.linux-kernel.target;

  initramfs = runCommand "spectrum-initramfs" {
    nativeBuildInputs = [ cpio ];
    passAsFile = [ "init" "mdevconf" ];
    init = ''
      #!/bin/execlineb -S0

      export PATH /bin

      if { mount -t devtmpfs none /dev }
      if { mount -t proc none /proc }
      if { mount -t sysfs none /sys }

      if { mkfifo /dev/esp.poll }

      background {
        fdclose 3
        mdevd -C
      }
      importas -iu mdevd_pid !

      if { modprobe squashfs }

      if {
        redirfd -r 0 /dev/esp.poll
        redirfd -w 1 /dev/null
        head -c 1
      }
      background { rm /dev/esp.poll }
      background { kill $mdevd_pid }

      backtick -E partname { readlink /dev/esp }
      backtick -E partpath { realpath /sys/class/block/''${partname} }
      backtick -E diskpath { realpath ''${partpath}/.. }
      backtick -E diskname { basename $diskpath }

      backtick -E rootdev {
        pipeline { lsblk -lnpo NAME,PARTTYPE /dev/''${diskname} }
        pipeline { grep -m 1 4f68bce3-e8cd-4db1-96e7-fbcaf984b709 }
        cut -d " " -f 1
      }

      background { rm /dev/esp }

      if { mount $rootdev /mnt }
      if { mount --move /proc /mnt/proc }
      if { mount --move /sys /mnt/sys }
      if { mount --move /dev /mnt/dev }

      switch_root /mnt /bin/sh -il
    '';
    mdevconf = ''
      -$MODALIAS=.* 0:0 660 +importas -iu MODALIAS MODALIAS modprobe $MODALIAS
      $DEVTYPE=partition 0:0 660 +importas -iu MDEV MDEV foreground { redirfd -w 2 /dev/null ln -s $MDEV /dev/esp } redirfd -w -nb 3 /dev/esp.poll echo
    '';
  } ''
    installPkg() {
        cp -r $1 root/nix/store
        ln -sf $1/bin/* root/bin
    }

    mkdir -p root/{bin,dev,etc,mnt,nix/store,proc,sys}
    installPkg ${busybox.override {
      enableStatic = true;
    }}
    installPkg ${pkgsStatic.mdevd}
    installPkg ${pkgsStatic.execline}
    cp -f ${pkgsStatic.utillinux.override { systemd = null; }}/bin/{blkid,findfs,lsblk} root/bin
    ln -s /bin root/sbin
    install $initPath root/init
    cp $mdevconfPath root/etc/mdev.conf
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
  - $efiSize      U                                    -
  - $squashfsSize 4f68bce3-e8cd-4db1-96e7-fbcaf984b709 -
  EOF

  fillPartition $out 0 ${efi}
  fillPartition $out 1 ${host-rootfs.squashfs}
''
