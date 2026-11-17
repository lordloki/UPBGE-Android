#!/usr/bin/env bash
# deps/recipes/zlib.sh
recipe_zlib() {
    local ver="1.3.1"
    local src="$SRC_DIR/zlib-$ver"
    if [ ! -d "$src" ]; then
        download_and_extract "https://zlib.net/fossils/zlib-$ver.tar.gz" "$src"
    fi
    cmake_android "$src" "$BUILD_DIR_BASE/zlib-$ARCH" \
        -DZLIB_BUILD_EXAMPLES=OFF
}
