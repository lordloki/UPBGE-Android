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
# The list of recipes is the same Wanderson uses, minus what `player-only`
# can drop. The `full` feature set enables the entire list.

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
FEATURE="${FEATURE:-player-only}"
JOBS="${JOBS:-$(nproc)}"
DEPS_PREFIX="${BUILD_BASE:-$HOME/upbge_android_build_base}/lib/android_${ARCH}"
SRC_DIR="${BUILD_BASE:-$HOME/upbge_android_build_base}/deps_src/${ARCH}"
BUILD_DIR_BASE="${BUILD_BASE:-$HOME/upbge_android_build_base}/deps_build/${ARCH}"
LOG_DIR="${BUILD_BASE:-$HOME/upbge_android_build_base}/logs"

usage() {
    cat <<EOF
usage: deps/build.sh [--arch ARCH] [--feature FEATURE] [--jobs N]

Cross-compile the UPBGE dependency prefix for Android.

  --arch ARCH       arm64-v8a (default) | armeabi-v7a
  --feature FEATURE player-only (default) | full
                    'full' enables extra heavy libs (TBB, Cycles deps, OIDN, ...)
  --jobs N          parallel jobs (default: nproc)

Outputs:
  $DEPS_PREFIX/lib/*.a, *.so
  $DEPS_PREFIX/include/...
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --arch) ARCH="$2"; shift 2;;
        --feature) FEATURE="$2"; shift 2;;
        --jobs) JOBS="$2"; shift 2;;
        -h|--help) usage; exit 0;;
        *) echo "unknown arg: $1" >&2; usage; exit 2;;
    esac
done

case "$ARCH" in
    arm64-v8a)   TRIPLET="aarch64-linux-android";;
    armeabi-v7a) TRIPLET="arm-linux-androideabi";;
    *) echo "unsupported arch: $ARCH" >&2; exit 2;;
esac

mkdir -p "$DEPS_PREFIX" "$SRC_DIR" "$BUILD_DIR_BASE" "$LOG_DIR"
DEPS_LOG="$LOG_DIR/deps_${ARCH}_${FEATURE}.log"
: > "$DEPS_LOG"

# -----------------------------------------------------------------------------
# Toolchain vars exported for every recipe
# -----------------------------------------------------------------------------
export ARCH TRIPLET FEATURE JOBS
export DEPS_PREFIX SRC_DIR BUILD_DIR_BASE
export NDK_HOST_OS_TAG="linux-x86_64"
export HOST_CC HOST_CXX
# pkg-config stub: there is no pkg-config on Android, so we provide a script
# that returns nothing but exit 0, and recipes use find_path/find_library
# directly instead.
export PKG_CONFIG="$(command -v pkg-config || true)"

# CMake toolchain reused by every recipe (custom, smaller than Blender's).
export DEPS_TOOLCHAIN="$ANDROID_DIR/toolchain/android.toolchain.cmake"

# -----------------------------------------------------------------------------
# Logging + error handling
# -----------------------------------------------------------------------------
log()  { echo "[deps] $*" | tee -a "$DEPS_LOG" >&2; }
fail() { echo "[deps] FAILED: $*" | tee -a "$DEPS_LOG" >&2; exit 1; }

step() {
    local name="$1"; shift
    local started; started="$(date +%s)"
    log ">>> $name"
    "$@" >>"$DEPS_LOG" 2>&1 || fail "$name failed (see $DEPS_LOG)"
    local elapsed=$(( $(date +%s) - started ))
    log "<<< $name (${elapsed}s)"
}

# -----------------------------------------------------------------------------
# Recipe loading
# -----------------------------------------------------------------------------
# The recipe list is ordered by dependency: later recipes may -I/-L against
# earlier ones. The order matches Wanderson's deps/build.sh as of 5.3.0-final.
PLAYER_ONLY_RECIPES=(
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
    openexr
    openjpeg
    tiff
    fftw3           # game engine audio
    sndfile
    flac
    vorbis
    ogg
    opus
    ffmpeg
    sdl2
    openal
    jpeg-xt         # 12-bit JPEG support, optional
    glew
    shaderc
    spirv-tools
    vulkan_headers
    vulkan_loader
    android_extra   # log, android_native_app_glue
)

FULL_RECIPES=(
    "${PLAYER_ONLY_RECIPES[@]}"
    tbb
    openvdb
    openimageio
    opensubdiv
    embree
    ceres
    gmp
    mpfr
    pugixml
    openpgl
    manifold
    draco
    openimagedenoise
    openshadinglanguage
    pystring
    hdf5
    alembic
    materialx
    usd
    potrace
    pcre2
    xml2
    iconv
    intl
    freetype_extras
)

if [ "$FEATURE" = "full" ]; then
    RECIPES=("${FULL_RECIPES[@]}")
else
    RECIPES=("${PLAYER_ONLY_RECIPES[@]}")
fi

# -----------------------------------------------------------------------------
# Run
# -----------------------------------------------------------------------------
log "BUILD_BASE  = $BUILD_BASE"
log "ARCH        = $ARCH"
log "TRIPLET     = $TRIPLET"
log "FEATURE     = $FEATURE"
log "DEPS_PREFIX = $DEPS_PREFIX"
log "recipes     = ${#RECIPES[@]}"
log ""

for r in "${RECIPES[@]}"; do
    recipe_file="$RECIPES_DIR/${r}.sh"
    if [ ! -f "$recipe_file" ]; then
        fail "recipe file missing: $recipe_file"
    fi
    # shellcheck disable=SC1090
    . "$recipe_file"
    if ! declare -F "recipe_${r}" >/dev/null; then
        fail "recipe ${r} does not define recipe_${r}()"
    fi
    step "${r}" "recipe_${r}"
done

log ""
log "All recipes complete."
log "  prefix : $DEPS_PREFIX"
log "  log    : $DEPS_LOG"
