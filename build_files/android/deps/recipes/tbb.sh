#!/usr/bin/env bash
# deps/recipes/tbb.sh
#
# oneTBB: Blender's parallel_for / task pools are serial without it.
# Static, unlike Blender's own (shared) build: a shared libtbb.so would carry
# a second copy of libc++_static, and the APK would have to ship it.
recipe_tbb() {
    local ver="v2022.3.0"  # UPBGE versions.cmake (TBB_VERSION)
    local src="$SRC_DIR/oneTBB-$ver"
    download_and_extract \
        "https://github.com/uxlfoundation/oneTBB/archive/refs/tags/$ver.tar.gz" \
        "$src"
    # TBB_STRICT turns warnings into errors (new NDK clang versions add some);
    # IPO would leave LLVM bitcode in the archive; tbbmalloc is unused
    # (WITH_TBB_MALLOC_PROXY is OFF); no hwloc on Android.
    cmake_android "$src" "$BUILD_DIR_BASE/tbb-$ARCH" \
        -DBUILD_SHARED_LIBS=OFF \
        -DTBB_TEST=OFF \
        -DTBB_EXAMPLES=OFF \
        -DTBB_STRICT=OFF \
        -DTBB_ENABLE_IPO=OFF \
        -DTBBMALLOC_BUILD=OFF \
        -DTBBMALLOC_PROXY_BUILD=OFF \
        -DTBB_DISABLE_HWLOC_AUTOMATIC_SEARCH=ON
    [ -f "$DEPS_PREFIX/lib/libtbb.a" ] || {
        echo "oneTBB did not install libtbb.a" >&2
        return 1
    }
}
