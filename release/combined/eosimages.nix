# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2021-2022 Alyssa Ross <hi@alyssa.is>

{ config ? import ../../nix/eval-config.nix {} }: with config.pkgs;

runCommand "eosimages.img" {
  nativeBuildInputs = [ e2fsprogs tar2ext4 ];
  imageName = "Spectrum-0.0-x86_64-generic.0.Live.img";
  image = import ../live { inherit config; };
} ''
  mkdir dir
  cd dir
  ln -s $image Spectrum-0.0-x86_64-generic.0.Live.img
  sha256sum $imageName > $imageName.sha256
  tar -chf $NIX_BUILD_TOP/eosimages.tar *
  tar2ext4 -i $NIX_BUILD_TOP/eosimages.tar -o $out
  e2label $out eosimages
''
