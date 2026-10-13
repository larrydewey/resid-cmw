#!/usr/bin/env bash
# Build ./resid-cmw. RESIDC picks the compiler (default: residc on PATH,
# else ~/.resid/bin/residc).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
RESIDC="${RESIDC:-$(command -v residc || echo "$HOME/.resid/bin/residc")}"
"$RESIDC" "$ROOT/resid-cmw.resid" -o "$ROOT/resid-cmw" > /dev/null
echo "built $ROOT/resid-cmw"
