#!/usr/bin/env bash
# OpenEXR 3.2 uses Imath as a separate project. Build Imath first into the same prefix.
recipe_openexr() {
    local ver=3.2.4 imath_ver=3.1.9 imath_src="$SRC_DIR/Imath-3.1.9"
    local exr_src="$SRC_DIR/openexr-$ver"
    download_and_extract "https://github.com/AcademySoftwareFoundation/Imath/archive/refs/tags/v$imath_ver.tar.gz" "$imath_src"
    cmake_android "$imath_src" "$BUILD_DIR_BASE/imath-$ARCH" \
        -DBUILD_TESTING=OFF -DPYTHON=OFF -DBUILD_SHARED_LIBS=OFF
    download_and_extract "https://github.com/AcademySoftwareFoundation/openexr/archive/refs/tags/v$ver.tar.gz" "$exr_src"
    cmake_android "$exr_src" "$BUILD_DIR_BASE/openexr-$ARCH" \
        -DCMAKE_PREFIX_PATH="$DEPS_PREFIX" -DImath_ROOT="$DEPS_PREFIX" \
        -DOPENEXR_BUILD_TOOLS=OFF -DOPENEXR_BUILD_EXAMPLES=OFF \
        -DOPENEXR_BUILD_TESTS=OFF -DOPENEXR_INSTALL_TOOLS=OFF \
        -DOPENEXR_INSTALL_EXAMPLES=OFF -DOPENEXR_INSTALL=ON \
        -DBUILD_SHARED_LIBS=OFF
}
