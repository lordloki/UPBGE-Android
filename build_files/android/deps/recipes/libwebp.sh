#!/usr/bin/env bash
# WebP codec libraries only; all command-line tools and animation utilities are off.
recipe_libwebp() {
    local ver="1.3.2"
    local src="$SRC_DIR/libwebp-$ver"
    download_and_extract "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-$ver.tar.gz" "$src"
    cmake_android "$src" "$BUILD_DIR_BASE/libwebp-$ARCH" \
        -DWEBP_BUILD_ANIM_UTILS=OFF -DWEBP_BUILD_CWEBP=OFF -DWEBP_BUILD_DWEBP=OFF \
        -DWEBP_BUILD_GIF2WEBP=OFF -DWEBP_BUILD_IMG2WEBP=OFF -DWEBP_BUILD_VWEBP=OFF \
        -DWEBP_BUILD_WEBPINFO=OFF -DWEBP_BUILD_WEBPMUX=OFF -DWEBP_BUILD_EXTRAS=OFF \
        -DWEBP_BUILD_LIBWEBPMUX=OFF -DWEBP_BUILD_LIBWEBPMUX=OFF
}
