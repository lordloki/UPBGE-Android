#!/usr/bin/env bash
# tsl::robin_map (header only): required by OpenImageIO.
recipe_robinmap() {
    local ver=v1.3.0
    local src="$SRC_DIR/robin-map-$ver"
    download_and_extract "https://github.com/Tessil/robin-map/archive/refs/tags/$ver.tar.gz" "$src"
    cmake_android "$src" "$BUILD_DIR_BASE/robinmap-$ARCH"
}
