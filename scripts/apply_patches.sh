#!/usr/bin/env bash
# scripts/apply_patches.sh
#
# Apply every Android patch to the UPBGE source tree, and copy the new files
# that have no upstream counterpart (GHOST_Android*.cc, android_main_wrapper.cc)
# into the right places.
#
# Idempotent: if a patch is already applied, `patch` will say "Reversed (or
# previously applied) patch detected!" and this script will skip it. Use
# --reset to wipe and re-clone the tree first.
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

apply "$PATCHES/0001-GHOST-Android-minimal-backend.patch" 1
# Dependency patches only apply once the deps source trees are checked out by
# deps/build.sh; record them so build.sh can find them.
echo "[apply_patches] dependency patches (oidn, glog) are applied on the fly by deps/recipes/*.sh"

# ----------------------------------------------------------------------------
# 2. Copy new files that have no upstream counterpart
# ----------------------------------------------------------------------------
copy() {
    local src="$1"
    local dst="$2"
    mkdir -p "$(dirname "$dst")"
    cp -v "$src" "$dst"
}

# GHOST Android backend
copy "$PATCHES/ghost_android/GHOST_SystemAndroid.hh" "$SRC/intern/ghost/intern/GHOST_SystemAndroid.hh"
copy "$PATCHES/ghost_android/GHOST_SystemAndroid.cc" "$SRC/intern/ghost/intern/GHOST_SystemAndroid.cc"
copy "$PATCHES/ghost_android/GHOST_WindowAndroid.hh"  "$SRC/intern/ghost/intern/GHOST_WindowAndroid.hh"
copy "$PATCHES/ghost_android/GHOST_WindowAndroid.cc"  "$SRC/intern/ghost/intern/GHOST_WindowAndroid.cc"
copy "$PATCHES/ghost_android/GHOST_AndroidMain.cc"    "$SRC/intern/ghost/intern/GHOST_AndroidMain.cc"

# Player entrypoint wrapper + CMake fragment
copy "$PATCHES/player_entrypoint/android_main_wrapper.cc" \
     "$SRC/source/gameengine/blenderplayer/android_main_wrapper.cc"
# Note: the CMakeLists.txt fragment is applied to the existing
# source/gameengine/blenderplayer/CMakeLists.txt by the patch above.
# To keep the change minimal, scripts/apply_patches.sh also renames main() →
# player_main() in main.cc:
MAIN_CC="$SRC/source/gameengine/blenderplayer/main.cc"
if [ -f "$MAIN_CC" ] && ! grep -q "player_main" "$MAIN_CC"; then
    echo "[apply_patches] renaming main() -> player_main() in $MAIN_CC"
    # In-place: replace 'int main(int argc' with 'int player_main(int argc'
    sed -i 's/^int main(int argc/int player_main(int argc/' "$MAIN_CC"
fi

echo "[apply_patches] done."
