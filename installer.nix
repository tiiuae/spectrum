{ lib, eos-installer, fetchurl }:

let
  logo = fetchurl {
    url = "https://spectrum-os.org/git/www/plain/logo/logo140.png?id=5ac2d787b12e05a9ea91e94ca9373ced55d7371a";
    sha256 = "008dkzapyrkbva3ziyb2fa1annjwfk28q9kwj1bgblgrq6sxllxk";
  };
in

eos-installer.overrideAttrs ({ postPatch ? "", ... }: {
  src = lib.cleanSource /home/src/eos-installer;

  postPatch = postPatch + ''
    find . -type f -print0 | xargs -0 sed -i 's/Endless OS/Spectrum/g'
    cp ${logo} gnome-image-installer/pages/finished/endless_logo.png
  '';
})
