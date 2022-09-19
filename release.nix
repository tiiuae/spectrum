# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2022 Alyssa Ross <hi@alyssa.is>

# This file is built to populate the binary cache.

# Set config = {} to disable implicitly reading config.nix, since
# we'll want the result to be the same as on the binary cache.  If it
# turns out there is a compelling reason to read the default config
# here, we can reconsider this.
{ config ? import nix/eval-config.nix { config = {}; } }:

{
  doc = import ./Documentation { inherit config; };

  combined = import release/combined/run-vm.nix { inherit config; };
}
