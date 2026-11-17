#!/usr/bin/env bash
# scripts/setup_host.sh
#
# Detect the Linux distro you are on and install every host prerequisite the
# UPBGE Android build needs: host compiler (GCC 14 or Clang 17+), CMake,
# Ninja, Python 3, JDK 17, autoconf/libtool/bison/flex, etc.
#
# Supported distros:
#   - Ubuntu 22.04 / 24.04 (apt)
#   - Debian 12+            (apt)
#   - openSUSE Tumbleweed   (zypper)
#   - openSUSE Leap 15.5+   (zypper, adds devel:gcc repo for gcc14)
#   - Fedora 39+            (dnf)
#   - Rocky / Alma / RHEL 9 (dnf)
#
# Idempotent: safe to re-run. Prints the JAVA_HOME and PATH exports you need
# to add to ~/.bashrc at the end.
#
# Usage:
#   scripts/setup_host.sh [--dry-run]
#       --dry-run    print the commands instead of running them.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

DRY_RUN=0
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift;;
        -h|--help)
            sed -n '2,30p' "${BASH_SOURCE[0]}"
            exit 0;;
        *) echo "unknown arg: $1" >&2; exit 2;;
    esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()  { echo "[setup_host] $*"; }
warn()  { echo "[setup_host] WARNING: $*" >&2; }
fail()  { echo "[setup_host] FAILED: $*" >&2; exit 1; }

run() {
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "  $ $*"
    else
        "$@"
    fi
}
run_sudo() {
    if [ "$DRY_RUN" -eq 1 ]; then
        echo "  $ sudo $*"
    else
        sudo "$@"
    fi
}

# ---------------------------------------------------------------------------
# 1. Detect distro via /etc/os-release
# ---------------------------------------------------------------------------
if [ ! -r /etc/os-release ]; then
    fail "cannot read /etc/os-release; this script supports Linux only"
fi
. /etc/os-release

DISTRO="${ID:-unknown}"
ID_LIKE="${ID_LIKE:-}"
VERSION="${VERSION_ID:-}"
PRETTY="${PRETTY_NAME:-$DISTRO $VERSION}"

info "detected: $PRETTY"
info "  ID=$DISTRO  VERSION=$VERSION  ID_LIKE=$ID_LIKE"

# ---------------------------------------------------------------------------
# 2. Dispatch
# ---------------------------------------------------------------------------
JAVA_HOME_OUT=""

install_debian() {
    info "apt-based install"
    run_sudo apt-get update
    run_sudo apt-get install -y --no-install-recommends \
        build-essential \
        gcc-14 g++-14 \
        clang-17 clang-format-17 clang-tidy-17 \
        cmake ninja-build \
        git curl wget unzip zip \
        python3 python3-pip python3-venv \
        openjdk-17-jdk-headless \
        pkg-config autoconf automake libtool bison flex \
        file texinfo ca-certificates
    run_sudo update-alternatives --install /usr/bin/gcc    gcc    /usr/bin/gcc-14    100 || true
    run_sudo update-alternatives --install /usr/bin/g++    g++    /usr/bin/g++-14    100 || true
    run_sudo update-alternatives --install /usr/bin/clang  clang  /usr/bin/clang-17  100 || true
    run_sudo update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-17 100 || true
    # JAVA_HOME on Debian/Ubuntu amd64
    if [ -d /usr/lib/jvm/java-17-openjdk-amd64 ]; then
        JAVA_HOME_OUT="/usr/lib/jvm/java-17-openjdk-amd64"
    elif [ -d /usr/lib/jvm/java-17-openjdk-arm64 ]; then
        JAVA_HOME_OUT="/usr/lib/jvm/java-17-openjdk-arm64"
    else
        # fall back to whatever java-17-openjdk-* exists
        JAVA_HOME_OUT="$(ls -d /usr/lib/jvm/java-17-openjdk-* 2>/dev/null | head -1)"
    fi
}

install_opensuse() {
    info "zypper-based install"
    # Leap 15.x does not ship gcc14 in the base repo; add devel:gcc.
    if [ "$DISTRO" = "opensuse-leap" ] || [ "$DISTRO" = "sle" ]; then
        local repo_url="https://download.opensuse.org/repositories/devel:/gcc/openSUSE_Leap_${VERSION}/"
        if [ "$DRY_RUN" -eq 1 ]; then
            echo "  $ sudo zypper ar -f $repo_url devel_gcc"
        else
            # Idempotent: only add if not present.
            if ! sudo zypper lr | grep -q devel_gcc; then
                sudo zypper ar -f "$repo_url" devel_gcc
            fi
        fi
        run_sudo zypper --gpg-auto-import-keys refresh
    else
        run_sudo zypper refresh
    fi

    # patterns-devel-base-devel_basis pulls in make, automake, etc.
    run_sudo zypper install -y \
        patterns-devel-base-devel_basis \
        gcc14 gcc14-c++ \
        clang17 clang17-tools \
        cmake ninja \
        git curl wget unzip zip \
        python311 python311-pip \
        java-17-openjdk-devel \
        pkgconf autoconf automake libtool bison flex \
        file texinfo

    # openSUSE installs gcc-14 as /usr/bin/gcc-14 (with hyphen).
    # update-alternatives gives us /usr/bin/gcc -> gcc-14.
    run_sudo update-alternatives --install /usr/bin/gcc    gcc    /usr/bin/gcc-14    100 || true
    run_sudo update-alternatives --install /usr/bin/g++    g++    /usr/bin/g++-14    100 || true
    run_sudo update-alternatives --install /usr/bin/clang  clang  /usr/bin/clang-17  100 || true
    run_sudo update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-17 100 || true

    # openSUSE puts JVM under /usr/lib64/jvm (note: lib64, not lib)
    if [ -d /usr/lib64/jvm/java-17-openjdk ]; then
        JAVA_HOME_OUT="/usr/lib64/jvm/java-17-openjdk"
    elif [ -d /usr/lib64/jvm/java-17-openjdk-17 ]; then
        JAVA_HOME_OUT="/usr/lib64/jvm/java-17-openjdk-17"
    else
        JAVA_HOME_OUT="$(ls -d /usr/lib64/jvm/java-17-openjdk* 2>/dev/null | head -1)"
    fi
}

install_fedora() {
    info "dnf-based install"
    run_sudo dnf install -y \
        @development-tools gcc gcc-c++ \
        clang clang-devel \
        cmake ninja-build \
        git curl wget unzip zip \
        python3 python3-pip \
        java-17-openjdk-devel \
        pkgconf-pkg-config autoconf automake libtool bison flex \
        file texinfo ca-certificates
    # Fedora has /usr/bin/gcc, /usr/bin/clang as the real binaries.
    if [ -d /usr/lib/jvm/java-17-openjdk ]; then
        JAVA_HOME_OUT="/usr/lib/jvm/java-17-openjdk"
    else
        JAVA_HOME_OUT="$(ls -d /usr/lib/jvm/java-17-openjdk* 2>/dev/null | head -1)"
    fi
}

case "$DISTRO" in
    ubuntu|debian|linuxmint|pop)
        install_debian;;
    opensuse-leap|opensuse-tumbleweed|suse|sles|opensuse)
        install_opensuse;;
    fedora|rhel|centos|rocky|alma|amzn)
        install_fedora;;
    *)
        # Fall back to ID_LIKE.
        case "$ID_LIKE" in
            *debian*)   install_debian;;
            *suse*)     install_opensuse;;
            *fedora*|*rhel*) install_fedora;;
            *)
                fail "unsupported distro: $DISTRO (ID_LIKE='$ID_LIKE').
This script supports Ubuntu/Debian, openSUSE Tumbleweed/Leap, Fedora, Rocky, Alma, RHEL.
For anything else, install the prerequisites manually — see docs/BUILD.md section 1."
                ;;
        esac
        ;;
esac

# ---------------------------------------------------------------------------
# 3. Verify
# ---------------------------------------------------------------------------
info "verification:"
for bin in gcc g++ clang clang++ cmake ninja python3 java; do
    if command -v "$bin" >/dev/null 2>&1; then
        ver="$("$bin" --version 2>&1 | head -1)"
        echo "  $bin: $ver"
    else
        warn "  $bin: NOT FOUND"
    fi
done

if [ -n "${JAVA_HOME_OUT:-}" ] && [ -d "$JAVA_HOME_OUT" ]; then
    echo "  JAVA_HOME: $JAVA_HOME_OUT"
else
    warn "  JAVA_HOME could not be auto-detected. Find your JDK 17 install and export JAVA_HOME manually."
fi

# ---------------------------------------------------------------------------
# 4. Print the exports to add to ~/.bashrc
# ---------------------------------------------------------------------------
cat <<EOF

[setup_host] done. Add these to ~/.bashrc (or source before building):

    export JAVA_HOME=${JAVA_HOME_OUT:-/usr/lib/jvm/java-17-openjdk}
    export ANDROID_HOME=\$HOME/Android/Sdk
    export ANDROID_NDK_VERSION=r26d
    export ANDROID_NDK_HOME=\$ANDROID_HOME/ndk/\$ANDROID_NDK_VERSION
    export ANDROID_NDK_ROOT=\$ANDROID_NDK_HOME
    export PATH=\$ANDROID_HOME/platform-tools:\$ANDROID_NDK_HOME:\$PATH

[setup_host] next steps:
    scripts/install_android_sdk.sh    # or: make setup-sdk
    make setup                        # clone UPBGE + apply patches
    make deps ARCH=arm64-v8a FEATURE=player-only
    make build-player ARCH=arm64-v8a
    make package  ARCH=arm64-v8a FEATURE=player-only
EOF
