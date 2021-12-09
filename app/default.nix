# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2021 Alyssa Ross <hi@alyssa.is>

{ lib, eos-installer, fetchurl, fetchpatch }:

let
  logo = fetchurl {
    url = "https://spectrum-os.org/git/www/plain/logo/logo140.png?id=5ac2d787b12e05a9ea91e94ca9373ced55d7371a";
    sha256 = "008dkzapyrkbva3ziyb2fa1annjwfk28q9kwj1bgblgrq6sxllxk";
  };
in

eos-installer.overrideAttrs ({ patches ? [], postPatch ? "", ... }: {
  patches = patches ++ [
    (fetchpatch {
      name = "finished-use-poweroff-from-PATH.patch";
      url = "https://github.com/endlessm/eos-installer/commit/a537fde1f2bc6bcbcd86a6e926aeeba824583e19.patch";
      sha256 = "0fl7254v78f9amzw774daap9rf46q6jw3pn7h4drj1jfqayk558j";
    })
    (fetchpatch {
      name = "diskimage-find-names-for-uncompressed-image-files.patch";
      url = "https://github.com/endlessm/eos-installer/commit/cb6f176ba0340a571efb8cb2f607d5d592b94c98.patch";
      sha256 = "1q5chzln0l81fwj279ak1pixga2wiqj6v98qf67lv69y16176pzm";
    })
    (fetchpatch {
      name = "Add-more-log-messages-for-invalid-disk-images.patch";
      url = "https://github.com/endlessm/eos-installer/commit/9a3a0c219e4bb1190ac995d0bbaa20816dd0618d.patch";
      sha256 = "0x22dlh1mqvlflr01iaqsb7b9vkcz06sbnfhcr5c6f3x2vzbp4jx";
    })
    ./0001-gpt-disable-gpt-partition-attribute-55-check.patch
    ./0002-gpt-disable-partition-table-CRC-check.patch
    ./0003-install-remove-Endless-OS-ad.patch
    ./0004-finished-don-t-run-eos-diagnostics.patch
    ./0005-finished-promote-spectrum-not-the-Endless-forum.patch
  ];

  postPatch = postPatch + ''
    find . -type f -print0 | xargs -0 sed -i 's/Endless OS/Spectrum/g'
    cp ${logo} gnome-image-installer/pages/finished/endless_logo.png
  '';
})
