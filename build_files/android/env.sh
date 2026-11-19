#!/usr/bin/env bash
# build_files/android/env.sh
# Source this file to get a consistent Android build environment.
# It does NOT overwrite variables the caller already exported.

# -----------------------------------------------------------------------------
# Initialize optional overrides because deps/build.sh sources this file with
# `set -u` enabled.
: "${HOST_CC:=}"
: "${HOST_CXX:=}"

# Host compiler: Blender's code generators (makesdna, makesrna, ...) need
# GCC >= 14 or Clang >= 17. Prefer Clang 19 on openSUSE Tumbleweed.
# -----------------------------------------------------------------------------
pick_host_cc() {
    if [ -z "$HOST_CC" ] || [ -z "$HOST_CXX" ]; then
        for c in clang-19 clang-18 clang-17 gcc-15 gcc-14 gcc clang cc; do
            local cxx="${c/gcc/g++}"
            cxx="${cxx/clang/clang++}"
            if command -v "$c" >/dev/null 2>&1 && command -v "$cxx" >/dev/null 2>&1; then
                [ -n "$HOST_CC" ] || HOST_CC="$(command -v "$c")"
                [ -n "$HOST_CXX" ] || HOST_CXX="$(command -v "$cxx")"
                break
            fi
        done
    fi
    if [ -z "$HOST_CC" ] || [ -z "$HOST_CXX" ]; then
        echo "env.sh: no suitable host compiler found (need gcc>=14 or clang>=17; Clang 19 is preferred)" >&2
        return 1
    fi
    export HOST_CC HOST_CXX
}

# -----------------------------------------------------------------------------
# Android SDK / NDK / JDK
# -----------------------------------------------------------------------------
: "${ANDROID_HOME:=$HOME/Android/Sdk}"
: "${ANDROID_NDK_VERSION:=r26d}"
: "${ANDROID_NDK_HOME:=$ANDROID_HOME/ndk/$ANDROID_NDK_VERSION}"
: "${ANDROID_NDK_ROOT:=$ANDROID_NDK_HOME}"
: "${JAVA_HOME:=/usr/lib/jvm/java-17-openjdk-amd64}"
: "${ANDROID_PLATFORM:=android-31}"
: "${ANDROID_TARGET_API:=34}"

# MinSdk / TargetSdk for the APK manifest
export ANDROID_MIN_SDK_VERSION=31
export ANDROID_TARGET_SDK_VERSION=34

# Make sure adb and the NDK are on PATH
if [ -d "$ANDROID_HOME/platform-tools" ]; then
    case ":$PATH:" in
        *"$ANDROID_HOME/platform-tools"*) ;;
        *) PATH="$ANDROID_HOME/platform-tools:$PATH" ;;
    esac
fi
if [ -d "$ANDROID_NDK_HOME" ]; then
    case ":$PATH:" in
        *"$ANDROID_NDK_HOME"*) ;;
        *) PATH="$ANDROID_NDK_HOME:$PATH" ;;
    esac
fi
export ANDROID_HOME ANDROID_NDK_VERSION ANDROID_NDK_HOME ANDROID_NDK_ROOT
export JAVA_HOME ANDROID_PLATFORM ANDROID_TARGET_API PATH

# -----------------------------------------------------------------------------
# Build base: where every produced artifact lives, OUTSIDE the source checkout.
# Resolution order: explicit $BUILD_BASE > env > $HOME/upbge_android_build_base.
# -----------------------------------------------------------------------------
: "${BUILD_BASE:=$HOME/upbge_android_build_base}"
export BUILD_BASE
mkdir -p "$BUILD_BASE"

# -----------------------------------------------------------------------------
# UPBGE source checkout (filled by scripts/fetch_upbge.sh)
# -----------------------------------------------------------------------------
: "${UPBGE_SOURCE:=$HOME/upbge_src}"
export UPBGE_SOURCE

# -----------------------------------------------------------------------------
# This system's root (parent of build_files/).
# -----------------------------------------------------------------------------
UPBGE_ANDROID_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export UPBGE_ANDROID_ROOT

# -----------------------------------------------------------------------------
# Sanity checks (only when sourced interactively, not from build.py).
# -----------------------------------------------------------------------------
env_check() {
    local missing=()
    [ -d "$ANDROID_HOME" ]         || missing+=("ANDROID_HOME ($ANDROID_HOME)")
    [ -d "$ANDROID_NDK_HOME" ]     || missing+=("ANDROID_NDK_HOME ($ANDROID_NDK_HOME)")
    [ -d "$JAVA_HOME" ]            || missing+=("JAVA_HOME ($JAVA_HOME)")
    command -v cmake >/dev/null    || missing+=("cmake")
    command -v ninja >/dev/null    || missing+=("ninja")
    command -v python3 >/dev/null  || missing+=("python3")
    [ -n "$HOST_CC" ]              || pick_host_cc || missing+=("HOST_CC")
    if [ ${#missing[@]} -gt 0 ]; then
        echo "env.sh: missing prerequisites:" >&2
        printf '  - %s\n' "${missing[@]}" >&2
        return 1
    fi
    echo "env.sh: ok"
    echo "  ANDROID_HOME     = $ANDROID_HOME"
    echo "  NDK              = $ANDROID_NDK_HOME"
    echo "  JAVA_HOME        = $JAVA_HOME"
    echo "  HOST_CC          = $HOST_CC"
    echo "  BUILD_BASE       = $BUILD_BASE"
    echo "  UPBGE_SOURCE     = $UPBGE_SOURCE"
}

# Always pick the host compiler when sourced.
pick_host_cc || true
