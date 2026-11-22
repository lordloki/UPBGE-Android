#!/usr/bin/env bash
# OpenJPEG library only; codec command-line programs are not needed by the player.
recipe_openjpeg() {
    local ver=2.5.2
    local src="$SRC_DIR/openjpeg-$ver"
    download_and_extract "https://github.com/uclouvain/openjpeg/archive/refs/tags/v$ver.tar.gz" "$src"
    cmake_android "$src" "$BUILD_DIR_BASE/openjpeg-$ARCH" \
        -DBUILD_CODEC=OFF -DBUILD_TESTING=OFF -DBUILD_DOC=OFF \
        -DBUILD_JPIP=OFF -DBUILD_THIRDPARTY=OFF -DBUILD_SHARED_LIBS=OFF
}
