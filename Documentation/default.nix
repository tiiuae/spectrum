# SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>
# SPDX-License-Identifier: MIT

{ pkgs ? import <nixpkgs> {} }: pkgs.callPackage (

{ lib, runCommand, jekyll, drawio-headless }:

runCommand "spectrum-docs" {
  src = with lib; cleanSourceWith {
    src = cleanSource ./.;
    filter = name: _type:
      builtins.baseNameOf name != ".jekyll-cache" &&
      builtins.baseNameOf name != "_site" &&
      !(hasSuffix ".nix" name) &&
      !(hasSuffix ".svg" name);
  };

  nativeBuildInputs = [ jekyll drawio-headless ];

  passthru = { inherit jekyll; };
}
  ''
  jekyll build --disable-disk-cache -b /doc -s $src -d $out
  drawio --recursive $out/diagrams/ --export -f svg $out/assets/images/
''
) {
  jekyll = import ./jekyll.nix { inherit pkgs; };
}
