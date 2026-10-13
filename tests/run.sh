#!/usr/bin/env bash
# Build resid-cmw, run tests/cases.sh, and compare its transcript with the
# golden tests/cases.out.
#
#   tests/run.sh            run the suite
#   tests/run.sh --update   rewrite tests/cases.out from the current output
#
# RESIDC picks the compiler (default: residc on PATH, else ~/.resid/bin/residc).
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RESIDC="${RESIDC:-$(command -v residc || echo "$HOME/.resid/bin/residc")}"
UPDATE=0
[ "${1:-}" = "--update" ] && UPDATE=1
W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT
export LC_ALL=C

CMW="$W/bin/resid-cmw"
mkdir -p "$W/bin"
"$RESIDC" "$ROOT/resid-cmw.resid" -o "$CMW" > "$W/compile.log" 2>&1 || {
    grep -v '^OK \|^note:\|^typecheck OK\|^wrote ' "$W/compile.log" | head -20
    echo "FAIL build"; exit 1
}
mkdir -p "$W/run"
W="$W/run" CMW="$CMW" bash -c 'source "$0"' "$ROOT/tests/cases.sh" > "$W/cases.out" 2>&1

if [ "$UPDATE" = 1 ]; then
    cp "$W/cases.out" "$ROOT/tests/cases.out"
    echo "updated tests/cases.out ($(grep -c '^\$ ' "$W/cases.out") commands)"
    exit 0
fi
if diff -u "$ROOT/tests/cases.out" "$W/cases.out"; then
    echo "PASS $(grep -c '^\$ ' "$W/cases.out") commands"
else
    echo "FAIL transcript differs"; exit 1
fi
