#!/usr/bin/env bash
# OpenJPH (HTJ2K): OpenEXR 3.4 depends on it. Built separately, as Blender
# does: a static OpenEXR with its vendored copy exports a link to an
# `openjph` target that is never installed, so consumers fail to configure.
recipe_openjph() {
    local ver=0.25.2
    local src="$SRC_DIR/OpenJPH-$ver"
    download_and_extract "https://github.com/aous72/OpenJPH/archive/refs/tags/$ver.tar.gz" "$src"
    cmake_android "$src" "$BUILD_DIR_BASE/openjph-$ARCH" \
        -DOJPH_BUILD_EXECUTABLES=OFF -DOJPH_BUILD_TESTS=OFF \
        -DOJPH_ENABLE_TIFF_SUPPORT=OFF
}
