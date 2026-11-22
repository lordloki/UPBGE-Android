#!/usr/bin/env bash
# yaml-cpp: required by OpenColorIO (config parsing).
recipe_yamlcpp() {
    local ver=0.8.0
    local src="$SRC_DIR/yaml-cpp-$ver"
    download_and_extract "https://github.com/jbeder/yaml-cpp/archive/refs/tags/$ver.tar.gz" "$src"
    cmake_android "$src" "$BUILD_DIR_BASE/yamlcpp-$ARCH" \
        -DYAML_CPP_BUILD_TESTS=OFF -DYAML_CPP_BUILD_TOOLS=OFF \
        -DYAML_CPP_BUILD_CONTRIB=OFF -DYAML_CPP_FORMAT_SOURCE=OFF \
        -DYAML_BUILD_SHARED_LIBS=OFF
}
