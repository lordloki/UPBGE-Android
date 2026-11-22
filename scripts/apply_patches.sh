#!/usr/bin/env bash
# scripts/apply_patches.sh
#
# Apply the Android patches (build_files/android/patches/upbge/*.patch, in
# order) to the UPBGE source tree:
#   0001  Blender-owned files (GHOST Vulkan context, gpu/vulkan), every hunk
#         marked "UPBGE - Android"
#   0002  UPBGE-owned files (source/gameengine/GamePlayer, source/blenderplayer),
#         including the new GamePlayer/android/ sources
#   0003  Blender-owned files: geometry shaders optional (Mali), marked as 0001
#   0004  UPBGE SpaceLogic DNA: deprecated array field that clang rejects
#
# Idempotent: an already applied patch is detected and skipped; one that does
# not fit stops the script. Use --reset to discard local changes first.
#
# Usage:
#   scripts/apply_patches.sh [--reset]

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/build_files/android/env.sh"

PATCHES="$ROOT/build_files/android/patches"
SRC="${UPBGE_SOURCE:?UPBGE_SOURCE is not set}"

RESET=0
while [ $# -gt 0 ]; do
    case "$1" in
        --reset) RESET=1; shift;;
        -h|--help)
            echo "usage: apply_patches.sh [--reset]"
            exit 0;;
        *) echo "unknown arg: $1" >&2; exit 2;;
    esac
done

if [ ! -d "$SRC/source/gameengine" ]; then
    echo "apply_patches.sh: $SRC does not look like UPBGE (no source/gameengine/)" >&2
    exit 1
fi

if [ "$RESET" -eq 1 ]; then
    echo "[apply_patches] --reset: git -C $SRC clean -fdx && git -C $SRC checkout ."
    git -C "$SRC" clean -fdx
    git -C "$SRC" checkout .
fi

# ----------------------------------------------------------------------------
# 1. Apply text patches
# ----------------------------------------------------------------------------
apply() {
    local patch="$1"
    local strip="${2:-1}"
    echo "[apply_patches] $patch"
    # Distinguish "already applied" from "does not fit": silently skipping a
    # rejected patch leaves a tree that configures but lacks the Android code.
    if patch -d "$SRC" -p"$strip" -R --dry-run -f < "$patch" >/dev/null 2>&1; then
        echo "  already applied — skipping"
    elif patch -d "$SRC" -p"$strip" --dry-run -f < "$patch" >/dev/null 2>&1; then
        patch -d "$SRC" -p"$strip" -f < "$patch"
    else
        echo "[apply_patches] FAILED: $patch does not apply to $SRC" >&2
        patch -d "$SRC" -p"$strip" --dry-run -f < "$patch" >&2 || true
        exit 1
    fi
}

shopt -s nullglob
patches=("$PATCHES"/upbge/*.patch)
if [ ${#patches[@]} -eq 0 ]; then
    echo "[apply_patches] no patches in $PATCHES/upbge" >&2
    exit 1
fi
for p in "${patches[@]}"; do
    apply "$p" 1
done

echo "[apply_patches] done."
