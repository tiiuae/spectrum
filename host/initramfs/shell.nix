# SPDX-License-Identifier: EUPL-1.2
# SPDX-FileCopyrightText: 2021-2022 Alyssa Ross <hi@alyssa.is>

{ pkgs ? import <nixpkgs> {} }:

with pkgs;

(import ./live.nix { inherit pkgs; }).overrideAttrs ({ ... }: {
  OVMF_FD = "${OVMF.fd}/FV/OVMF.fd";
})
