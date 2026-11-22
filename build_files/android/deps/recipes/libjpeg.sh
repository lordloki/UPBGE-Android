#!/usr/bin/env bash
# deps/recipes/libjpeg.sh
# Uses libjpeg-turbo, which is what Wanderson ships too.
recipe_libjpeg() {
    local ver="3.0.0"
    local src="$SRC_DIR/libjpeg-turbo-$ver"
    download_and_extract \
        "https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/$ver/libjpeg-turbo-$ver.tar.gz" \
        "$src"
    # SIMD on: arm64 uses NEON intrinsics (no NASM needed) and decodes 2-4x
    # faster. It only had to be off while the toolchain reported x86_64.
    cmake_android "$src" "$BUILD_DIR_BASE/libjpeg-$ARCH" \
        -DENABLE_SHARED=OFF \
        -DENABLE_STATIC=ON \
        -DWITH_SIMD=ON \
        -DWITH_TURBOJPEG=OFF
}
