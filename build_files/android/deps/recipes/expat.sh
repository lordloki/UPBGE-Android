#!/usr/bin/env bash
# Expat: required by OpenColorIO.
recipe_expat() {
    local ver=2_7_5
    local src="$SRC_DIR/libexpat-$ver"
    download_and_extract "https://github.com/libexpat/libexpat/archive/R_$ver.tar.gz" "$src"
    cmake_android "$src/expat" "$BUILD_DIR_BASE/expat-$ARCH" \
        -DEXPAT_BUILD_DOCS=OFF -DEXPAT_BUILD_EXAMPLES=OFF \
        -DEXPAT_BUILD_TESTS=OFF -DEXPAT_BUILD_TOOLS=OFF \
        -DEXPAT_SHARED_LIBS=OFF
}
