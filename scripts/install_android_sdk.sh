#!/usr/bin/env bash
# scripts/install_android_sdk.sh
#
# Install the Android SDK command-line tools, platform-tools, platform
# android-34, build-tools 34.0.0 and NDK r26d into $ANDROID_HOME
# (default: $HOME/Android/Sdk). Idempotent: re-runs only install what is
# missing.
#
# Works on any Linux distro that has curl/wget and unzip. Run after
# scripts/setup_host.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Default values mirror build_files/android/env.sh
ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
NDK_VERSION="${ANDROID_NDK_VERSION:-r26d}"
ANDROID_PLATFORM="${ANDROID_PLATFORM:-android-31}"
ANDROID_TARGET_API="${ANDROID_TARGET_API:-34}"
BUILD_TOOLS_VER="${ANDROID_BUILD_TOOLS:-34.0.0}"

# commandlinetools version pinned (matches the URL Wanderson implicitly uses)
CMDLINE_VER="11076708"
CMDLINE_URL="https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_VER}_latest.zip"

info()  { echo "[install_android_sdk] $*"; }
fail()  { echo "[install_android_sdk] FAILED: $*" >&2; exit 1; }

# Make sure unzip + curl are available
for bin in curl unzip; do
    command -v "$bin" >/dev/null 2>&1 || fail "$bin is not installed; run scripts/setup_host.sh first"
done

mkdir -p "$ANDROID_HOME"

# ---------------------------------------------------------------------------
# 1. command-line tools (sdkmanager)
# ---------------------------------------------------------------------------
# sdkmanager expects to live at $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager
# When you unzip cmdline-tools.zip you get $ANDROID_HOME/cmdline-tools/{bin,lib}
# directly — so we move them into a "latest" subdirectory.
SDKMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager"

if [ ! -x "$SDKMANAGER" ]; then
    info "downloading command-line tools"
    tmp_zip="$(mktemp -d)/cmdline-tools.zip"
    curl -fL --retry 3 -o "$tmp_zip" "$CMDLINE_URL"

    # If a previous broken cmdline-tools dir exists, wipe it first.
    rm -rf "$ANDROID_HOME/cmdline-tools"
    unzip -q "$tmp_zip" -d "$ANDROID_HOME"
    rm -f "$tmp_zip"

    # Restructure: cmdline-tools/{bin,lib,...} → cmdline-tools/latest/{bin,lib,...}
    if [ -d "$ANDROID_HOME/cmdline_tools" ]; then
        # newer archives use cmdline_tools/ (underscore) instead of cmdline-tools/
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
# 2. Accept licenses + install packages
# ---------------------------------------------------------------------------
info "accepting SDK licenses"
yes | "$SDKMANAGER" --licenses > /dev/null 2>&1 || true

info "installing: platform-tools, platforms;android-${ANDROID_TARGET_API#android-}, build-tools;${BUILD_TOOLS_VER}, ndk;${NDK_VERSION}"
"$SDKMANAGER" \
    "platform-tools" \
    "platforms;android-${ANDROID_TARGET_API#android-}" \
    "build-tools;${BUILD_TOOLS_VER}" \
    "ndk;${NDK_VERSION}"

# ---------------------------------------------------------------------------
# 3. Verify
# ---------------------------------------------------------------------------
info "verification:"
"$ANDROID_HOME/platform-tools/adb" version 2>&1 | head -1 | sed 's/^/  adb: /'
ls -d "$ANDROID_HOME/ndk/$NDK_VERSION/toolchains/llvm/prebuilt"/*/bin/aarch64-linux-android*-clang \
    2>/dev/null | head -1 | sed 's/^/  ndk clang: /' || warn "NDK clang not found"

# ---------------------------------------------------------------------------
# 4. Print env
# ---------------------------------------------------------------------------
cat <<EOF

[install_android_sdk] done. SDK installed at:
    $ANDROID_HOME

Add these to ~/.bashrc (or source before building):

    export ANDROID_HOME=$ANDROID_HOME
    export ANDROID_NDK_VERSION=$NDK_VERSION
    export ANDROID_NDK_HOME=\$ANDROID_HOME/ndk/\$ANDROID_NDK_VERSION
    export ANDROID_NDK_ROOT=\$ANDROID_NDK_HOME
    export PATH=\$ANDROID_HOME/platform-tools:\$ANDROID_NDK_HOME:\$PATH

[install_android_sdk] next steps:
    make setup      # clone UPBGE + apply patches
    make deps       # cross-compile dependencies
EOF
