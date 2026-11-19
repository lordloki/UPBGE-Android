#!/usr/bin/env bash
# TIFF library with optional compression backends disabled unless already in prefix.
recipe_tiff() {
    local ver=4.6.0 src="$SRC_DIR/tiff-$ver"
    download_and_extract "https://download.osgeo.org/libtiff/tiff-$ver.tar.gz" "$src"
    cmake_android "$src" "$BUILD_DIR_BASE/tiff-$ARCH" \
        -Dtiff-tools=OFF -Dtiff-tests=OFF -Dtiff-docs=OFF \
        -Dtiff-jbig=OFF -Dtiff-lerc=OFF -Dtiff-webp=OFF \
        -Dtiff-zstd=ON -Dtiff-zlib=ON -Dtiff-jpeg=ON
}
