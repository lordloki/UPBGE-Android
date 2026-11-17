#!/usr/bin/env bash
# deps/recipes/lz4.sh
recipe_lz4() {
    local ver="1.9.4"
    local src="$SRC_DIR/lz4-$ver"
    if [ ! -d "$src" ]; then
        download_and_extract \
            "https://github.com/lz4/lz4/releases/download/v$ver/lz4-$ver.tar.gz" \
            "$src"
    fi
    cmake_android "$src/build/cmake" "$BUILD_DIR_BASE/lz4-$ARCH" \
        -DLZ4_BUILD_CLI=OFF \
        -DBUILD_STATIC_LIBS=ON
}
