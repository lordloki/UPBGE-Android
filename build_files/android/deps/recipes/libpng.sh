#!/usr/bin/env bash
# deps/recipes/libpng.sh
recipe_libpng() {
    local ver="1.6.58"
    local src="$SRC_DIR/libpng-$ver"
    download_and_extract \
        "https://downloads.sourceforge.net/libpng/libpng-$ver.tar.xz" \
        "$src"
    cmake_android "$src" "$BUILD_DIR_BASE/libpng-$ARCH" \
        -DPNG_SHARED=OFF -DPNG_STATIC=ON \
        -DPNG_TESTS=OFF -DPNG_TOOLS=OFF \
        -DPNG_HARDWARE_OPTIMIZATIONS=ON \
        -DZLIB_LIBRARY="$DEPS_PREFIX/lib/libz.a" \
        -DZLIB_INCLUDE_DIR="$DEPS_PREFIX/include"
}
