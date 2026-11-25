#!/usr/bin/env bash
# deps/recipes/zstd.sh
recipe_zstd() {
    local ver="1.5.7"
    local src="$SRC_DIR/zstd-$ver"
    download_and_extract \
        "https://github.com/facebook/zstd/releases/download/v$ver/zstd-$ver.tar.gz" \
        "$src"
    # zstd ships a CMakeLists.txt under build/cmake
    cmake_android "$src/build/cmake" "$BUILD_DIR_BASE/zstd-$ARCH" \
        -DZSTD_BUILD_PROGRAMS=OFF \
        -DZSTD_BUILD_STATIC=ON \
        -DZSTD_BUILD_SHARED=OFF
}
