#!/usr/bin/env bash
# build_files/android/deps/build.sh
#
# Cross-compile every library the UPBGE blenderplayer needs into
# $BUILD_BASE/lib/android_<arch>. This is the "deps prefix" that build.py's
# CMake finds through CMAKE_FIND_ROOT_PATH.
#
# Recipes live in deps/recipes/*.sh and follow this contract:
#   - They are sourced, not executed, so they can share helpers below.
#   - Each one defines: recipe_<name>() { ... }
#   - They install into $DEPS_PREFIX.
#
# The recipe list is the subset of Wanderson's deps/build.sh that the
# `player-only` feature set needs.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
RECIPES_DIR="$SCRIPT_DIR/recipes"

# shellcheck source=../env.sh
. "$ANDROID_DIR/env.sh"

# -----------------------------------------------------------------------------
# CLI
# -----------------------------------------------------------------------------
ARCH="${ARCH:-arm64-v8a}"
JOBS="${JOBS:-$(nproc)}"
DEPS_PREFIX="${BUILD_BASE:-$HOME/upbge_android_build_base}/lib/android_${ARCH}"
SRC_DIR="${BUILD_BASE:-$HOME/upbge_android_build_base}/deps_src/${ARCH}"
BUILD_DIR_BASE="${BUILD_BASE:-$HOME/upbge_android_build_base}/deps_build/${ARCH}"
LOG_DIR="${BUILD_BASE:-$HOME/upbge_android_build_base}/logs"

FORCE=0
ONLY=""

usage() {
    cat <<EOF
usage: deps/build.sh [--arch ARCH] [--jobs N] [--only NAME] [--force]

Cross-compile the UPBGE dependency prefix for Android (player-only).

  --arch ARCH       arm64-v8a (default; only target supported)
  --jobs N          parallel jobs (default: nproc)
  --only NAME       build only this recipe (implies --force for it)
  --force           rebuild recipes that already completed

Completed recipes are skipped on the next run (stamps in
$BUILD_DIR_BASE/.stamps). A stamp is invalidated when the recipe, the
shared helpers or the toolchain file change.

Outputs:
  $DEPS_PREFIX/lib/*.a
  $DEPS_PREFIX/include/...
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --arch) ARCH="$2"; shift 2;;
        --jobs) JOBS="$2"; shift 2;;
        --only) ONLY="$2"; FORCE=1; shift 2;;
        --force) FORCE=1; shift;;
        -h|--help) usage; exit 0;;
        *) echo "unknown arg: $1" >&2; usage; exit 2;;
    esac
done

case "$ARCH" in
    arm64-v8a)   TRIPLET="aarch64-linux-android";;
    *) echo "unsupported arch: $ARCH (only arm64-v8a is supported)" >&2; exit 2;;
esac

if [ ! -f "$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" ]; then
    echo "[deps] Android NDK not found at ANDROID_NDK_HOME=$ANDROID_NDK_HOME" >&2
    echo "[deps] run scripts/install_android_sdk.sh (make setup-sdk) or export ANDROID_NDK_HOME" >&2
    exit 1
fi

STAMP_DIR="$BUILD_DIR_BASE/.stamps"
mkdir -p "$DEPS_PREFIX" "$SRC_DIR" "$BUILD_DIR_BASE" "$LOG_DIR" "$STAMP_DIR"
DEPS_LOG="$LOG_DIR/deps_${ARCH}.log"
: > "$DEPS_LOG"

# -----------------------------------------------------------------------------
# Toolchain vars exported for every recipe
# -----------------------------------------------------------------------------
export ARCH TRIPLET JOBS
export DEPS_PREFIX SRC_DIR BUILD_DIR_BASE
export NDK_HOST_OS_TAG="linux-x86_64"
export HOST_CC HOST_CXX
# pkg-config only sees the .pc files of the deps prefix. Those files contain
# absolute host paths, so PKG_CONFIG_SYSROOT_DIR must stay unset (it would be
# prepended to every -I/-L), and PKG_CONFIG_PATH must not add host .pc files.
PKG_CONFIG="$(command -v pkg-config || true)"
export PKG_CONFIG
export PKG_CONFIG_LIBDIR="$DEPS_PREFIX/lib/pkgconfig:$DEPS_PREFIX/share/pkgconfig"
unset PKG_CONFIG_SYSROOT_DIR PKG_CONFIG_PATH
# openSUSE exports CONFIG_SITE, which makes every autoconf configure install
# into lib64. Autoconf skips /dev/null explicitly.
export CONFIG_SITE=/dev/null

# CMake toolchain reused by every recipe (thin wrapper over the NDK one).
export DEPS_TOOLCHAIN="$ANDROID_DIR/toolchain/android.toolchain.cmake"

# -----------------------------------------------------------------------------
# Logging + error handling
# -----------------------------------------------------------------------------
log()  { echo "[deps] $*" | tee -a "$DEPS_LOG" >&2; }
fail() { echo "[deps] FAILED: $*" | tee -a "$DEPS_LOG" >&2; exit 1; }

step() {
    local name="$1"; shift
    local started rc; started="$(date +%s)"
    log ">>> $name"
    # Bash ignores `set -e` inside anything run as the left operand of `||`,
    # including function bodies and subshells: a failing configure would fall
    # through to make/install and the recipe would "succeed" or fail far from
    # the cause. Run the recipe as a plain statement in a subshell with errexit
    # active, and collect the status afterwards.
    set +e
    ( set -euo pipefail; "$@" ) >>"$DEPS_LOG" 2>&1
    rc=$?
    set -e
    if [ "$rc" -ne 0 ]; then
        echo "[deps] ---- last lines of $DEPS_LOG ----" >&2
        tail -n 40 "$DEPS_LOG" >&2
        fail "$name failed (rc=$rc, see $DEPS_LOG)"
    fi
    local elapsed=$(( $(date +%s) - started ))
    log "<<< $name (${elapsed}s)"
}

# A stamp records the hash of everything that defines how a recipe is built.
recipe_hash() {
    cat "$RECIPES_DIR/$1.sh" "$RECIPES_DIR/_helpers.sh" "$DEPS_TOOLCHAIN" \
        | sha256sum | cut -d' ' -f1
}

# Load common helpers before individual recipes.
. "$RECIPES_DIR/_helpers.sh"

# -----------------------------------------------------------------------------
# Recipe loading
# -----------------------------------------------------------------------------
# The recipe list is ordered by dependency: later recipes may -I/-L against
# earlier ones. This is the player-only dependency set; optional codecs not
# required by the runtime are deliberately excluded.
RECIPES=(
    zlib
    zstd
    lz4
    libpng
    libjpeg
    libwebp
    freetype
    gettext
    sqlite
    python
    boost
    openjpeg
    tiff
    openexr
    fftw3           # game engine audio
    ogg
    flac
    vorbis
    opus
    sndfile
    ffmpeg
    sdl2
    openal
    glew
    spirv-tools
    shaderc
    vulkan_headers
    vulkan_loader
    android_extra   # log, android_native_app_glue
)

# -----------------------------------------------------------------------------
# Run
# -----------------------------------------------------------------------------
log "BUILD_BASE  = $BUILD_BASE"
log "ARCH        = $ARCH"
log "TRIPLET     = $TRIPLET"
log "DEPS_PREFIX = $DEPS_PREFIX"
log "recipes     = ${#RECIPES[@]}"
log ""

if [ -n "$ONLY" ] && [[ " ${RECIPES[*]} " != *" $ONLY "* ]]; then
    fail "--only $ONLY: not in the active recipe list"
fi

for r in "${RECIPES[@]}"; do
    if [ -n "$ONLY" ] && [ "$r" != "$ONLY" ]; then
        continue
    fi
    recipe_file="$RECIPES_DIR/${r}.sh"
    if [ ! -f "$recipe_file" ]; then
        fail "recipe file missing: $recipe_file"
    fi
    stamp="$STAMP_DIR/${r}.done"
    hash="$(recipe_hash "$r")"
    if [ "$FORCE" -eq 0 ] && [ -f "$stamp" ] && [ "$(cat "$stamp")" = "$hash" ]; then
        log "--- ${r} (up to date)"
        continue
    fi
    rm -f "$stamp"
    # shellcheck disable=SC1090
    . "$recipe_file"
    if ! declare -F "recipe_${r}" >/dev/null; then
        fail "recipe ${r} does not define recipe_${r}()"
    fi
    step "${r}" "recipe_${r}"
    printf '%s\n' "$hash" > "$stamp"
done

# Static linking is only guaranteed if no shared object can shadow an archive:
# CMake's find_library() prefers .so over .a. libvulkan.so is the NDK link
# stub for the system loader and is the only shared object expected here.
stray_so="$(find "$DEPS_PREFIX/lib" -maxdepth 1 -name '*.so*' ! -name 'libvulkan.so' -print)"
if [ -n "$stray_so" ]; then
    log "WARNING: shared libraries in the deps prefix (would be linked dynamically):"
    printf '%s\n' "$stray_so" | sed 's/^/  /' | tee -a "$DEPS_LOG" >&2
fi

log ""
log "All recipes complete."
log "  prefix : $DEPS_PREFIX"
log "  log    : $DEPS_LOG"
