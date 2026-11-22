#!/usr/bin/env bash
# OpenColorIO: required by Blender (>= 2.3) and by OpenImageIO.
# Static library; its installed CMake config re-finds expat, yaml-cpp,
# pystring, Imath, ZLIB and minizip-ng for consumers.
# On non-Apple aarch64 OCIO selects no SSE paths, so sse2neon is not used here.
recipe_opencolorio() {
    local ver=2.5.0
    local src="$SRC_DIR/OpenColorIO-$ver"
    download_and_extract "https://github.com/AcademySoftwareFoundation/OpenColorIO/archive/v$ver.tar.gz" "$src"
    cmake_android "$src" "$BUILD_DIR_BASE/opencolorio-$ARCH" \
        -DOCIO_BUILD_APPS=OFF -DOCIO_BUILD_PYTHON=OFF -DOCIO_BUILD_NUKE=OFF \
        -DOCIO_BUILD_JAVA=OFF -DOCIO_BUILD_OPENFX=OFF -DOCIO_BUILD_DOCS=OFF \
        -DOCIO_BUILD_TESTS=OFF -DOCIO_BUILD_GPU_TESTS=OFF \
        -DOCIO_USE_SIMD=ON -DOCIO_INSTALL_EXT_PACKAGES=NONE \
        -Dexpat_ROOT="$DEPS_PREFIX" \
        -Dyaml-cpp_ROOT="$DEPS_PREFIX" \
        -Dpystring_ROOT="$DEPS_PREFIX" \
        -DImath_ROOT="$DEPS_PREFIX" \
        -Dminizip-ng_ROOT="$DEPS_PREFIX" \
        -Dminizip-ng_INCLUDE_DIR="$DEPS_PREFIX/include/minizip" \
        -Dminizip-ng_LIBRARY="$DEPS_PREFIX/lib/libminizip.a" \
        -DZLIB_LIBRARY="$DEPS_PREFIX/lib/libz.a" \
        -DZLIB_INCLUDE_DIR="$DEPS_PREFIX/include"
}
