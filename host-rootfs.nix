{ runCommand, writeReferencesToFile, squashfs-tools-ng, busybox }:

let
  rootfs = runCommand "rootfs" {} ''
    mkdir $out
    cd $out

    mkdir -p bin dev proc sys
    ln -s ${busybox}/bin/* bin/
  '';

  squashfs = runCommand "root-squashfs" {
    passthru.extracted = rootfs;
  } ''
    cd ${rootfs}
    (
        grep -v ^${rootfs} ${writeReferencesToFile rootfs}
        printf "%s\n" *
    ) \
        | xargs tar -cP --owner root:0 --group root:0 --hard-dereference \
        | ${squashfs-tools-ng}/bin/tar2sqfs -c gzip -X level=1 $out
  '';
in
squashfs
