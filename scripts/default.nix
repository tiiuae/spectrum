# SPDX-License-Identifier: EUPL-1.2
# SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>

{ pkgs ? import <nixpkgs> {} }:

pkgs.lib.cleanSource ./.
