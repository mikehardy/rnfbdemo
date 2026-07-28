#!/bin/bash
# Operator helper: write ~/packages/.rnfb-local-pack-meta.json after packing.
#
# Run after create_npm_packages.sh (or any re-pack of ~/packages/*.tgz) and
# before matrix demos (make-demo.sh / make-expo-demo.sh). Finalize/verify only
# reads this meta — it does not rewrite it.
#
# Usage:
#   ./write-local-pack-meta.sh
#   ./write-local-pack-meta.sh /path/to/RNFB/checkout
#   RNFB_SOURCE_CHECKOUT=/path/to/checkout ./write-local-pack-meta.sh
#
# Default checkout: $HOME/work/invertase/RNFB-worktrees/v26-validation-fixes
# (override via $1 or RNFB_SOURCE_CHECKOUT).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common-functions.sh
source "${SCRIPT_DIR}/common-functions.sh"

DEFAULT_CHECKOUT="${HOME}/work/invertase/RNFB-worktrees/v26-validation-fixes"
source_checkout="${1:-${RNFB_SOURCE_CHECKOUT:-${DEFAULT_CHECKOUT}}}"

writeRnfbLocalPackMeta "${source_checkout}"
