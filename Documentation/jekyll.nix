# SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>
# SPDX-License-Identifier: MIT

{ pkgs ? import <nixpkgs> {} }: pkgs.callPackage (

{ lib, bundlerApp, defaultGemConfig, fetchFromGitHub, fetchpatch }:

bundlerApp {
  pname = "jekyll";
  gemdir = ./.;
  exes = [ "jekyll" ];

  gemConfig = defaultGemConfig // {
    # We override Just the Docs to improve AsciiDoc support.
    just-the-docs = attrs:
      let super = defaultGemConfig.just-the-docs or (lib.const {}) attrs; in
      super // {
        # The gem tarball doesn't contain e.g. the SCSS files.
        src = fetchFromGitHub {
          owner = "just-the-docs";
          repo = "just-the-docs";
          rev = assert attrs.version == "0.3.3"; "8bc53f8f45ce6a11be0559c764d39d90f2434ec1";
          sha256 = "sha256-pvct9Ob/TzTZvj2YVZ36FtU2Uo465p3aUc0NCd/0oWo=";
        };

        patches = super.patches or attrs.patches or [] ++ [
          (fetchpatch {
            url = "https://github.com/just-the-docs/just-the-docs/compare/3a834d24ab1bda72f481f1e630f28fb9ba78ce64...7627fdb73decc0dd9264729a4ac302065c81bf24.patch";
            sha256 = "sha256-5jWAlNvkCPu/U4aTrzal8GxoWmcSSKiKAwzu5pjCrPE=";
          })

          # Don't use domains in links, which would require different
          # configuration when running locally vs on the website.
          # https://github.com/just-the-docs/just-the-docs/pull/544
          (fetchpatch {
            url = "https://github.com/just-the-docs/just-the-docs/commit/7bb40aa3c71d989339322ad946cfdd8287717a94.patch";
            sha256 = "sha256-3e6N1B9lAgSYVRMLLvhsfOP5CXuespKJk/pyGdbK4wg=";
          })
        ];

        postPatch = ''
          substituteInPlace just-the-docs.gemspec \
              --replace 'git ls-files -z' 'find * -print0'
        '';
      };
  };
}
) { }
