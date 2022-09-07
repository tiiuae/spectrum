#! /usr/bin/env nix-shell
#! nix-shell -i bash -p bundler bundix
# SPDX-FileCopyrightText: 2022 Unikie
# SPDX-License-Identifier: EUPL-1.2+

set -euo pipefail

bundle lock --update
bundix -l
