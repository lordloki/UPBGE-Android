#!/usr/bin/env bash
# deps/recipes/openal.sh
#
# openal-soft has a CMake-based Android backend that uses OpenSL ES under the
# hood (bundled in the NDK). This is what we use for game audio on Android.
recipe_openal() {
    local ver="1.23.1"
    local src="$SRC_DIR/openal-$ver"
    download_and_extract \
        "https://github.com/kcat/openal-soft/releases/download/$ver/openal-soft-$ver.tar.bz2" \
        "$src"
    # openal-soft ignores BUILD_SHARED_LIBS and builds libopenal.so unless
    # LIBTYPE=STATIC; a shared copy would have to be packaged in the APK.
    # The final link must add OpenSLES (and log) for the static archive.
    cmake_android "$src" "$BUILD_DIR_BASE/openal-$ARCH" \
        -DLIBTYPE=STATIC \
        -DALSOFT_UTILS=OFF \
        -DALSOFT_EXAMPLES=OFF \
        -DALSOFT_INSTALL_CONFIG=OFF \
        -DALSOFT_INSTALL_HRTF_DATA=OFF \
        -DALSOFT_INSTALL_AMBDEC_PRESETS=OFF \
        -DALSOFT_INSTALL_EXAMPLES=OFF \
        -DALSOFT_INSTALL_UTILS=OFF \
        -DALSOFT_BACKEND_OSS=OFF \
        -DALSOFT_BACKEND_OPENSL=ON \
        -DALSOFT_REQUIRE_OPENSL=ON \
        -DALSOFT_BACKEND_WAVE=OFF
}
