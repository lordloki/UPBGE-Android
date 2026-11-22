#!/usr/bin/env bash
# TIFF library with optional compression backends disabled unless already in prefix.
recipe_tiff() {
    local ver=4.6.0
    local src="$SRC_DIR/tiff-$ver"
    download_and_extract "https://download.osgeo.org/libtiff/tiff-$ver.tar.gz" "$src"
    # Codec options carry no "tiff-" prefix in libtiff 4.6 (cmake/*Codec.cmake);
    # the prefixed names were silently ignored and codecs were auto-detected.
    cmake_android "$src" "$BUILD_DIR_BASE/tiff-$ARCH" \
        -Dtiff-tools=OFF -Dtiff-tests=OFF -Dtiff-docs=OFF -Dtiff-contrib=OFF \
        -Djbig=OFF -Dlerc=OFF -Dwebp=OFF -Dlzma=OFF -Dlibdeflate=OFF \
        -Dzstd=ON -Dzlib=ON -Djpeg=ON
}
