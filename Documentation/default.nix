# SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>
# SPDX-FileCopyrightText: 2022 Unikie
# SPDX-License-Identifier: MIT

{ config ? import ../nix/eval-config.nix {} }: config.pkgs.callPackage (

{ lib, stdenvNoCC, jekyll, drawio-headless }:

stdenvNoCC.mkDerivation {
  name = "spectrum-docs";

  src = with lib; cleanSourceWith {
    src = cleanSource ./.;
    filter = name: _type:
      builtins.baseNameOf name != ".jekyll-cache" &&
      builtins.baseNameOf name != "_site" &&
      !(hasSuffix ".nix" name) &&
      !(hasSuffix ".svg" name);
  };

  buildPhase = ''
    runHook preBuild
    scripts/build.sh $out
    runHook postBuild
  '';

  dontInstall = true;

  nativeBuildInputs = [ jekyll drawio-headless ];

  passthru = { inherit jekyll; };
}
) {
  jekyll = import ./jekyll.nix { inherit config; };
}
