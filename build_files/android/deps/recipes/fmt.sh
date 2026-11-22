#!/usr/bin/env bash
# {fmt}: required by Blender (platform_unix) and by OpenImageIO.
# Version pinned to UPBGE's build_environment/cmake/versions.cmake.
recipe_fmt() {
    local ver=12.1.0
    local src="$SRC_DIR/fmt-$ver"
    download_and_extract "https://github.com/fmtlib/fmt/archive/refs/tags/$ver.tar.gz" "$src"
    cmake_android "$src" "$BUILD_DIR_BASE/fmt-$ARCH" \
        -DFMT_TEST=OFF -DFMT_DOC=OFF -DFMT_INSTALL=ON
}
