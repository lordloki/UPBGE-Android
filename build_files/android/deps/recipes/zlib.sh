#!/usr/bin/env bash
# deps/recipes/zlib.sh
recipe_zlib() {
    local ver="1.3.1"
    local src="$SRC_DIR/zlib-$ver"
    download_and_extract "https://zlib.net/fossils/zlib-$ver.tar.gz" "$src"
    cmake_android "$src" "$BUILD_DIR_BASE/zlib-$ARCH" \
        -DZLIB_BUILD_EXAMPLES=OFF
    # zlib 1.3.1 always builds libz.so too; find_library() would prefer it
    # over libz.a and the player would bind to the platform's zlib instead.
    rm -f "$DEPS_PREFIX"/lib/libz.so*
}
