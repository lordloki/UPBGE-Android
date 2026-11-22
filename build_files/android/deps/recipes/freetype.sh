#!/usr/bin/env bash
# deps/recipes/freetype.sh
recipe_freetype() {
    local ver="2.13.2"
    local src="$SRC_DIR/freetype-$ver"
    download_and_extract \
        "https://downloads.sourceforge.net/freetype/freetype-$ver.tar.gz" \
        "$src"
    cmake_android "$src" "$BUILD_DIR_BASE/freetype-$ARCH" \
        -DFT_DISABLE_HARFBUZZ=ON \
        -DFT_DISABLE_BZIP2=ON \
        -DFT_DISABLE_BROTLI=ON \
        -DFT_REQUIRE_ZLIB=ON \
        -DZLIB_LIBRARY="$DEPS_PREFIX/lib/libz.a" \
        -DZLIB_INCLUDE_DIR="$DEPS_PREFIX/include" \
        -DBUILD_SHARED_LIBS=OFF
}
