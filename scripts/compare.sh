#!/usr/bin/env bash
# compare.sh — Build all candidates, run against lorem-ipsum DB, measure sizes.
# Usage: ./scripts/compare.sh [--no-build] [--only=<candidate>]
#
# Sets the DB to read-only (444) before testing so write attempts by libs
# that need RW don't accidentally modify it.

set -euo pipefail

cd "$(dirname "$0")/.."

DB=fixtures/sample.db
# Baseline binary: point at agent-detect's installed dist binary.
# Search order: $BASELINE_DIR env, then ~/Projects/vibe/agent-detect/bin,
# then ~/Projects/vibe/agent-detection/bin (legacy local repo name).
if [ -z "${BASELINE_DIR:-}" ]; then
    for candidate in \
        "$HOME/Projects/vibe/agent-detect/bin" \
        "$HOME/Projects/vibe/agent-detection/bin"; do
        if [ -d "$candidate" ]; then
            BASELINE_DIR="$candidate"
            break
        fi
    done
    if [ -z "${BASELINE_DIR:-}" ]; then
        echo ">>> WARNING: no baseline dir found; deltas will equal absolute sizes"
        BASELINE_DIR=""
    fi
fi
BASELINE_OSX_ARM64="$BASELINE_DIR/agent-detect-macos-aarch64"

build=false
only=""
for arg in "$@"; do
    case "$arg" in
        --no-build) build=false ;;
        --build) build=true ;;
        --only=*) only="${arg#--only=}" ;;
        *) echo "unknown arg: $arg" >&2; exit 1 ;;
    esac
done

# Restore DB
echo ">>> restoring test DB from seed"
chmod 644 "$DB" 2>/dev/null || true
rm -f "$DB" "$DB-shm" "$DB-wal"
sqlite3 "$DB" < fixtures/seed.sql
chmod 444 "$DB" 2>/dev/null || true

candidates=(vrischmann karlseguin zsql zsqlx ndimensional muhammad-fiaz cli-shim)

if [ -n "$only" ]; then
    candidates=("$only")
fi

# Baseline size
baseline=0
if [ -f "$BASELINE_OSX_ARM64" ]; then
    baseline=$(wc -c < "$BASELINE_OSX_ARM64" | tr -d ' ')
    echo ">>> baseline (macos-aarch64): $baseline bytes"
else
    echo ">>> WARNING: no baseline at $BASELINE_OSX_ARM64"
fi

for c in "${candidates[@]}"; do
    cd "candidates/$c"
    echo
    echo "=========================================="
    echo ">>> candidate: $c"
    echo "=========================================="
    if [ "$build" != "false" ]; then
        echo ">>> building $c"
        zig build --prefix . 2>&1 | tail -3 || true
    fi
    exe=$(ls bin/${c}-*-macos-aarch64 2>/dev/null | head -1 || echo "")
    if [ -z "$exe" ]; then
        # cli-shim uses cli-shim-* prefix, ndimensional uses ndim-*
        exe=$(ls bin/*-macos-aarch64 2>/dev/null | head -1 || echo "")
    fi
    if [ -z "$exe" ]; then
        echo ">>> NO BINARY"
        cd ../..
        continue
    fi
    size=$(wc -c < "bin/$(basename $exe)" | tr -d ' ')
    delta=$((size - baseline))
    echo ">>> size: $size bytes (delta: +$delta)"
    echo ">>> run:"
    cd bin && ./$(basename $exe) 2>&1 | head -8 || true
    cd ../../..
done

cd "$(dirname "$0")/.."

echo
echo "=========================================="
echo ">>> summary"
echo "=========================================="
for c in "${candidates[@]}"; do
    exe=$(ls "candidates/$c/bin"/*-macos-aarch64 2>/dev/null | head -1 || echo "")
    if [ -n "$exe" ] && [ -f "$exe" ]; then
        size=$(wc -c < "$exe" | tr -d ' ')
        delta=$((size - baseline))
        printf "%-20s %8s bytes  (+%s)\n" "$c" "$size" "$delta"
    fi
done