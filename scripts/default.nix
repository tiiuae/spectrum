# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>

{ pkgs ? import <nixpkgs> {} }:

pkgs.lib.cleanSource ./.
