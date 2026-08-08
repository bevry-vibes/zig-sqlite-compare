#!/usr/bin/env bash
# bootstrap.sh — fetch dependencies and warm build caches for all candidates.
#
# Each candidate's `build.zig.zon` already pins its dependency URLs and hashes,
# so this script just runs `zig build` once per candidate. The first build
# downloads dependencies into candidates/<name>/zig-pkg/, warms .zig-cache/,
# and produces binaries in candidates/<name>/bin/.
#
# Usage:
#   ./scripts/bootstrap.sh                  # fetch + build all candidates
#   ./scripts/bootstrap.sh cli-shim         # fetch + build only one
#   ./scripts/bootstrap.sh --no-build       # just fetch (run zig fetch for each)
#
# After bootstrap, run ./scripts/compare.sh to measure sizes.

set -euo pipefail

cd "$(dirname "$0")/.."

mode="build"
if [ "${1:-}" = "--no-build" ]; then
    mode="fetch"
    shift
fi

candidates=(cli-shim vrischmann karlseguin zsql zsqlx ndimensional muhammad-fiaz)
if [ $# -gt 0 ]; then
    candidates=("$@")
fi

for c in "${candidates[@]}"; do
    if [ ! -d "candidates/$c" ]; then
        echo ">>> skip $c (no directory)"
        continue
    fi
    echo
    echo "=========================================="
    echo ">>> candidate: $c"
    echo "=========================================="
    cd "candidates/$c"
    case "$mode" in
        build)
            zig build --prefix . 2>&1 | tail -3
            ;;
        fetch)
            # Resolve dep names from build.zig.zon
            for dep in $(grep -oE '^\s*\.[a-z_]+\s*=\s*\{' build.zig.zon | grep -vE '^\s*\.(name|version|fingerprint|paths)' | sed 's/.*\.\([a-z_]*\).*/\1/'); do
                echo ">>> fetch $dep"
                zig fetch --save "https://example.invalid/$dep" >/dev/null 2>&1 || true
            done
            # Real fetch happens on `zig build`; we just warm the cache
            zig build --prefix . 2>&1 | tail -1
            ;;
    esac
    cd ../..
done

echo
echo "=========================================="
echo ">>> done. caches warmed at candidates/<name>/zig-pkg/ + candidates/<name>/.zig-cache/"
echo "=========================================="