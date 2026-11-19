#!/usr/bin/env bash
# FLAC static library; disable command-line tools and tests.
recipe_flac() {
    local ver=1.4.3 src="$SRC_DIR/flac-$ver"
    download_and_extract "https://downloads.xiph.org/releases/flac/flac-$ver.tar.xz" "$src"
    cmake_android "$src" "$BUILD_DIR_BASE/flac-$ARCH" \
        -DBUILD_CXXLIBS=OFF -DBUILD_PROGRAMS=OFF -DBUILD_EXAMPLES=OFF \
        -DBUILD_TESTING=OFF -DBUILD_DOCS=OFF -DWITH_OGG=ON \
        -DOGG_INCLUDE_DIR="$DEPS_PREFIX/include" -DOGG_LIBRARY="$DEPS_PREFIX/lib/libogg.a"
}
