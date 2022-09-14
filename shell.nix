# SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>
# SPDX-FileCopyrightText: 2022 Unikie
# SPDX-License-Identifier: MIT

{ config ? import nix/eval-config.nix {} }: with config.pkgs;

mkShell {
  nativeBuildInputs = [ b4 reuse rustfmt ];

  shellHook = ''
    declare -igx GIT_CONFIG_COUNT
    export "GIT_CONFIG_KEY_''${GIT_CONFIG_COUNT:-0}"=b4.midmask
    export "GIT_CONFIG_VALUE_''${GIT_CONFIG_COUNT:-0}"=https://spectrum-os.org/lists/archives/spectrum-devel/%s
    GIT_CONFIG_COUNT+=1
  '';
}
