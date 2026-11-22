#!/usr/bin/env bash
# deps/recipes/brotli.sh
#
# FreeType decodes WOFF2 (Blender's bundled UI and text fonts) with Brotli, and
# Blender's configure refuses a FreeType built without it.
recipe_brotli() {
    local ver="1.0.10"  # UPBGE versions.cmake (BROTLI_VERSION)
    local src="$SRC_DIR/brotli-$ver"
    download_and_extract \
        "https://github.com/google/brotli/archive/refs/tags/v$ver.tar.gz" \
        "$src"
    cmake_android "$src" "$BUILD_DIR_BASE/brotli-$ARCH" \
        -DBROTLI_DISABLE_TESTS=ON
    # 1.0.x always builds shared and *-static variants; keep only the archives.
    rm -f "$DEPS_PREFIX"/lib/libbrotli*.so*
    local lib
    for lib in common dec; do
        [ -f "$DEPS_PREFIX/lib/libbrotli$lib-static.a" ] || {
            echo "brotli did not install libbrotli$lib-static.a" >&2
            return 1
        }
    done
}
