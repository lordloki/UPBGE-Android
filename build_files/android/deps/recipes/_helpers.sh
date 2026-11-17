#!/usr/bin/env bash
# deps/recipes/_helpers.sh
# Common helpers sourced by every recipe. deps/build.sh sources this file
# before sourcing any recipe, so recipes can call these directly.

# Download a tarball/zip and extract it into the given dir.
# Usage: download_and_extract URL DEST_DIR
download_and_extract() {
    local url="$1"
    local dest="$2"
    local cache="$SRC_DIR/.downloads"
    mkdir -p "$cache" "$dest"
    local fname; fname="$(basename "$url")"
    local archive="$cache/$fname"
    if [ ! -s "$archive" ]; then
        echo "  downloading $url"
        curl -fL --retry 3 -o "$archive" "$url"
    fi
    case "$fname" in
        *.tar.gz|*.tgz)    tar -xzf "$archive" -C "$dest" --strip-components=1;;
        *.tar.bz2|*.tbz2)  tar -xjf "$archive" -C "$dest" --strip-components=1;;
        *.tar.xz|*.txz)    tar -xJf "$archive" -C "$dest" --strip-components=1;;
        *.zip)             unzip -q "$archive" -d "$dest";;
        *) echo "unknown archive format: $fname" >&2; return 1;;
    esac
}

# Run a CMake build with the standard Android toolchain + install prefix.
# Usage: cmake_android SRC_DIR BUILD_DIR [extra cmake args...]
cmake_android() {
    local src="$1"; local bld="$2"; shift 2
    mkdir -p "$bld"
    cmake -G Ninja -S "$src" -B "$bld" \
        -DCMAKE_TOOLCHAIN_FILE="$DEPS_TOOLCHAIN" \
        -DANDROID_ABI="$ARCH" \
        -DANDROID_PLATFORM="android-31" \
        -DANDROID_NDK="$ANDROID_NDK_HOME" \
        -DCMAKE_INSTALL_PREFIX="$DEPS_PREFIX" \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        "$@"
    cmake --build "$bld" --target install -- -j"$JOBS"
}

# Some libraries misbehave with -DCMAKE_BUILD_TYPE=Release and need Debug for
# host tools. Use this variant when the recipe needs Debug.
cmake_android_debug() {
    local src="$1"; local bld="$2"; shift 2
    cmake -G Ninja -S "$src" -B "$bld" \
        -DCMAKE_TOOLCHAIN_FILE="$DEPS_TOOLCHAIN" \
        -DANDROID_ABI="$ARCH" \
        -DANDROID_PLATFORM="android-31" \
        -DANDROID_NDK="$ANDROID_NDK_HOME" \
        -DCMAKE_INSTALL_PREFIX="$DEPS_PREFIX" \
        -DCMAKE_BUILD_TYPE=Debug \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        "$@"
    cmake --build "$bld" --target install -- -j"$JOBS"
}
