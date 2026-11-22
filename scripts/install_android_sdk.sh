#!/usr/bin/env bash
# scripts/install_android_sdk.sh
#
# Install the Android SDK command-line tools, platform-tools, platform
# android-34, build-tools 34.0.0 and NDK r26d into $ANDROID_HOME
# (default: $HOME/Android/Sdk). Idempotent: re-runs only install what is
# missing.
#
# IMPORTANT: the NDK is downloaded as a direct .zip from
#   https://dl.google.com/android/repository/android-ndk-r26d-linux.zip
# instead of via `sdkmanager "ndk;r26d"`. Recent versions of the Android
# command-line tools only accept the exact numeric package name
# (e.g. `ndk;26.3.11579264`) — the short `rXX` alias is no longer recognized
# and the numeric name changes with every NDK patch release. The direct
# download URL is stable: Google keeps every NDK release permanently at
#   https://dl.google.com/android/repository/android-ndk-r<rev>-linux.zip
#
# Works on any Linux distro that has curl/wget and unzip. Run after
# scripts/setup_host.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Default values mirror build_files/android/env.sh
ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
NDK_VERSION="${ANDROID_NDK_VERSION:-r26d}"
NDK_DIR_NAME="android-ndk-${NDK_VERSION}"
NDK_INSTALL_NAME="${NDK_VERSION}"   # final dir name under $ANDROID_HOME/ndk/
ANDROID_PLATFORM="${ANDROID_PLATFORM:-android-31}"
ANDROID_TARGET_API="${ANDROID_TARGET_API:-34}"
BUILD_TOOLS_VER="${ANDROID_BUILD_TOOLS:-34.0.0}"

# commandlinetools version pinned (the URL is stable; if Google ever removes
# it, bump CMDLINE_VER to a newer value).
CMDLINE_VER="11076708"
CMDLINE_URL="https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_VER}_latest.zip"

# Direct NDK download URL (always works, no sdkmanager quirks).
NDK_ZIP_URL="https://dl.google.com/android/repository/${NDK_DIR_NAME}-linux.zip"

info()  { echo "[install_android_sdk] $*"; }
warn()  { echo "[install_android_sdk] WARNING: $*" >&2; }
fail()  { echo "[install_android_sdk] FAILED: $*" >&2; exit 1; }

# Make sure unzip + curl are available
for bin in curl unzip; do
    command -v "$bin" >/dev/null 2>&1 || fail "$bin is not installed; run scripts/setup_host.sh first"
done

mkdir -p "$ANDROID_HOME"

# ---------------------------------------------------------------------------
# 1. command-line tools (sdkmanager) — only if missing
# ---------------------------------------------------------------------------
SDKMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"

if [ ! -x "$SDKMANAGER" ]; then
    info "downloading command-line tools"
    tmp_zip="$(mktemp -d)/cmdline-tools.zip"
    curl -fL --retry 3 -o "$tmp_zip" "$CMDLINE_URL"

    # If a previous broken cmdline-tools dir exists, wipe it first.
    rm -rf "$ANDROID_HOME/cmdline-tools" "$ANDROID_HOME/cmdline_tools"
    unzip -q "$tmp_zip" -d "$ANDROID_HOME"
    rm -f "$tmp_zip"

    # Restructure: cmdline-tools/{bin,lib,...} → cmdline-tools/latest/{bin,lib,...}
    # (some archives use cmdline_tools/ with underscore)
    if [ -d "$ANDROID_HOME/cmdline_tools" ]; then
        mv "$ANDROID_HOME/cmdline_tools" "$ANDROID_HOME/cmdline-tools"
    fi
    mkdir -p "$ANDROID_HOME/cmdline-tools/latest"
    for item in bin lib NOTICE source.properties; do
        [ -e "$ANDROID_HOME/cmdline-tools/$item" ] && \
            mv "$ANDROID_HOME/cmdline-tools/$item" "$ANDROID_HOME/cmdline-tools/latest/$item"
    done
fi

[ -x "$SDKMANAGER" ] || fail "sdkmanager not at $SDKMANAGER after install"

# ---------------------------------------------------------------------------
# 2. Accept licenses + install SDK packages via sdkmanager
# ---------------------------------------------------------------------------
info "accepting SDK licenses"
yes | "$SDKMANAGER" --licenses > /dev/null 2>&1 || true

info "installing SDK packages via sdkmanager: platform-tools, platforms;android-${ANDROID_TARGET_API#android-}, build-tools;${BUILD_TOOLS_VER}"
"$SDKMANAGER" \
    "platform-tools" \
    "platforms;android-${ANDROID_TARGET_API#android-}" \
    "build-tools;${BUILD_TOOLS_VER}"

# ---------------------------------------------------------------------------
# 3. NDK r26d — installed from the direct .zip URL (NOT via sdkmanager).
#    This is the fix for: "Failed to find package 'ndk;r26d'" on cmdline-tools 16+.
# ---------------------------------------------------------------------------
NDK_INSTALL_DIR="$ANDROID_HOME/ndk/$NDK_INSTALL_NAME"

# NDK r19+ has no unversioned <triple>-clang wrapper; checking for one made
# every run re-download the ~600 MB archive. Check what deps/build.sh needs.
if [ ! -x "$NDK_INSTALL_DIR/toolchains/llvm/prebuilt/linux-x86_64/bin/clang" ] || \
   [ ! -f "$NDK_INSTALL_DIR/build/cmake/android.toolchain.cmake" ]; then
    info "downloading NDK $NDK_VERSION from direct URL"
    info "  $NDK_ZIP_URL"
    tmp_ndk_zip="$(mktemp -d)/ndk.zip"
    curl -fL --retry 3 -o "$tmp_ndk_zip" "$NDK_ZIP_URL"

    # The archive extracts to a top-level directory named
    # android-ndk-r26d/  — unpack into a temp dir, then move/rename into
    # $ANDROID_HOME/ndk/$NDK_VERSION (the path env.sh expects).
    tmp_extract="$(mktemp -d)"
    unzip -q "$tmp_ndk_zip" -d "$tmp_extract"
    rm -f "$tmp_ndk_zip"

    # Find the extracted directory (should be exactly one).
    extracted_dir="$(find "$tmp_extract" -maxdepth 1 -mindepth 1 -type d | head -1)"
    [ -d "$extracted_dir" ] || fail "NDK archive did not extract a top-level directory"

    mkdir -p "$ANDROID_HOME/ndk"
    rm -rf "$NDK_INSTALL_DIR"
    mv "$extracted_dir" "$NDK_INSTALL_DIR"
    rm -rf "$tmp_extract"
else
    info "NDK $NDK_VERSION already present, skipping download"
fi

# ---------------------------------------------------------------------------
# 4. Verify
# ---------------------------------------------------------------------------
info "verification:"
"$ANDROID_HOME/platform-tools/adb" version 2>&1 | head -1 | sed 's/^/  adb: /'
ls "$NDK_INSTALL_DIR/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android31-clang" \
    2>/dev/null | head -1 | sed 's/^/  ndk clang: /' || warn "NDK clang not found"

# ---------------------------------------------------------------------------
# 5. Print env
# ---------------------------------------------------------------------------
cat <<EOF

[install_android_sdk] done. SDK installed at:
    $ANDROID_HOME
    NDK at: $NDK_INSTALL_DIR

Add these to ~/.bashrc (or source before building):

    export ANDROID_HOME=$ANDROID_HOME
    export ANDROID_NDK_VERSION=$NDK_VERSION
    export ANDROID_NDK_HOME=$NDK_INSTALL_DIR
    export ANDROID_NDK_ROOT=$NDK_INSTALL_DIR
    export PATH=\$ANDROID_HOME/platform-tools:\$ANDROID_NDK_HOME:\$PATH

[install_android_sdk] next steps:
    make setup      # clone UPBGE + apply patches
    make deps       # cross-compile dependencies
EOF
