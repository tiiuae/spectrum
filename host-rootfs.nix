{ runCommand, writeReferencesToFile, tar2ext4, busybox }:

let
  rootfs = runCommand "rootfs" {} ''
    mkdir $out
    cd $out

    mkdir -p bin dev proc sys
    ln -s ${busybox}/bin/* bin/
  '';

  ext4 = runCommand "root-ext4" {
    nativeBuildInputs = [ tar2ext4 ];
    passthru.extracted = rootfs;
  } ''
    cd ${rootfs}
    (
        grep -v ^${rootfs} ${writeReferencesToFile rootfs}
        printf "%s\n" *
    ) | tar -cPf $NIX_BUILD_TOP/rootfs.tar --verbatim-files-from -T - \
        --hard-dereference --owner root:0 --group root:0
    tar2ext4 -i $NIX_BUILD_TOP/rootfs.tar -o $out
  '';
in
ext4
