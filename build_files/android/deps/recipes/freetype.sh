#!/usr/bin/env bash
# deps/recipes/freetype.sh
#
# Same options as Blender's build_environment (freetype.cmake): Brotli for
# WOFF2, zlib, no PNG/HarfBuzz/BZip2.
recipe_freetype() {
    local ver="2.13.3"
    local src="$SRC_DIR/freetype-$ver"
    download_and_extract \
        "https://downloads.sourceforge.net/freetype/freetype-$ver.tar.gz" \
        "$src"
    cmake_android "$src" "$BUILD_DIR_BASE/freetype-$ARCH" \
        -DFT_DISABLE_HARFBUZZ=ON \
        -DFT_DISABLE_BZIP2=ON \
        -DFT_DISABLE_PNG=ON \
        -DFT_REQUIRE_BROTLI=ON \
        -DBROTLIDEC_INCLUDE_DIRS="$DEPS_PREFIX/include" \
        -DBROTLIDEC_LIBRARIES="$DEPS_PREFIX/lib/libbrotlidec-static.a;$DEPS_PREFIX/lib/libbrotlicommon-static.a" \
        -DFT_REQUIRE_ZLIB=ON \
        -DZLIB_LIBRARY="$DEPS_PREFIX/lib/libz.a" \
        -DZLIB_INCLUDE_DIR="$DEPS_PREFIX/include" \
        -DBUILD_SHARED_LIBS=OFF

    # Without LIBDIR, Blender links only the library FindFreetype returns, so
    # Brotli would be left unresolved. Merge it into libfreetype.a (link-time
    # only; --gc-sections drops whatever is unused).
    local ar="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$NDK_HOST_OS_TAG/bin/llvm-ar"
    local lib="$DEPS_PREFIX/lib"
    "$ar" -M <<EOF
create $lib/libfreetype.merged.a
addlib $lib/libfreetype.a
addlib $lib/libbrotlidec-static.a
addlib $lib/libbrotlicommon-static.a
save
end
EOF
    mv -f "$lib/libfreetype.merged.a" "$lib/libfreetype.a"
}
