#!/usr/bin/env bash
# pystring: required by OpenColorIO. v1.1.3 ships no CMakeLists.txt (and the
# one in v1.1.4 forces a shared library without installing the header), so
# provide the same minimal static build Blender's build_environment uses.
recipe_pystring() {
    local ver=v1.1.3
    local src="$SRC_DIR/pystring-$ver"
    download_and_extract "https://github.com/imageworks/pystring/archive/refs/tags/$ver.tar.gz" "$src"
    cat > "$src/CMakeLists.txt" <<'EOF'
# SPDX-License-Identifier: BSD-3-Clause
# Copyright Contributors to the OpenColorIO Project.
cmake_minimum_required(VERSION 3.10)
project(pystring CXX)
add_library(pystring STATIC pystring.cpp)
set_target_properties(pystring PROPERTIES PUBLIC_HEADER pystring.h)
install(TARGETS pystring
    ARCHIVE DESTINATION lib
    PUBLIC_HEADER DESTINATION include/pystring)
EOF
    cmake_android "$src" "$BUILD_DIR_BASE/pystring-$ARCH"
}
