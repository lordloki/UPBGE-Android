#!/usr/bin/env bash
# deps/recipes/openal.sh
#
# openal-soft has a CMake-based Android backend that uses OpenSL ES under the
# hood (bundled in the NDK). This is what we use for game audio on Android.
recipe_openal() {
    local ver="1.23.1"
    local src="$SRC_DIR/openal-$ver"
    if [ ! -d "$src" ]; then
        download_and_extract \
            "https://github.com/kcat/openal-soft/releases/download/$ver/openal-soft-$ver.tar.bz2" \
            "$src"
    fi
    cmake_android "$src" "$BUILD_DIR_BASE/openal-$ARCH" \
        -DALSOFT_UTILS=OFF \
        -DALSOFT_EXAMPLES=OFF \
        -DALSOFT_TESTS=OFF \
        -DALSOFT_BACKEND_OSS=OFF \
        -DALSOFT_BACKEND_OPENSL=ON \
        -DALSOFT_REQUIRE_OPENSL=ON \
        -DALSOFT_BACKEND_WAVE=OFF
}
