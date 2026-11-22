#!/usr/bin/env bash
# sse2neon (single header): required by Blender on ARM (Findsse2neon REQUIRED
# when the compiler supports NEON). Commit pinned to UPBGE's versions.cmake.
recipe_sse2neon() {
    local ver=227cc413fb2d50b2a10073087be96b59d5364aea
    local src="$SRC_DIR/sse2neon-$ver"
    download_and_extract "https://github.com/DLTcollab/sse2neon/archive/$ver.tar.gz" "$src"
    mkdir -p "$DEPS_PREFIX/include"
    cp -f "$src/sse2neon.h" "$DEPS_PREFIX/include/sse2neon.h"
}
