#!/usr/bin/env bash
# libsndfile: use only codecs built earlier in the dependency sequence.
recipe_sndfile() {
    local ver=1.2.2
    local src="$SRC_DIR/libsndfile-$ver"
    download_and_extract "https://github.com/libsndfile/libsndfile/releases/download/$ver/libsndfile-$ver.tar.xz" "$src"
    cmake_android "$src" "$BUILD_DIR_BASE/sndfile-$ARCH" \
        -DBUILD_PROGRAMS=OFF -DBUILD_EXAMPLES=OFF -DBUILD_TESTING=OFF \
        -DBUILD_REGTEST=OFF -DENABLE_EXTERNAL_LIBS=ON \
        -DENABLE_MPEG=OFF -DENABLE_CPACK=OFF \
        -DOgg_ROOT="$DEPS_PREFIX" -DVorbis_ROOT="$DEPS_PREFIX" -DFLAC_ROOT="$DEPS_PREFIX"
}
