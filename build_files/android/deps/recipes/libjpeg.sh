#!/usr/bin/env bash
# deps/recipes/libjpeg.sh
# Uses libjpeg-turbo, which is what Wanderson ships too.
recipe_libjpeg() {
    local ver="3.0.0"
    local src="$SRC_DIR/libjpeg-turbo-$ver"
    if [ ! -d "$src" ]; then
        download_and_extract \
            "https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/$ver/libjpeg-turbo-$ver.tar.gz" \
            "$src"
    fi
    cmake_android "$src" "$BUILD_DIR_BASE/libjpeg-$ARCH" \
        -DENABLE_SHARED=OFF \
        -DENABLE_STATIC=ON \
        -DWITH_SIMD=OFF \
        -DWITH_TURBOJPEG=OFF
}
