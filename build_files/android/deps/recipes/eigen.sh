#!/usr/bin/env bash
# Eigen (header only): required by Blender (platform_unix: Eigen3 REQUIRED).
# Commit pinned to UPBGE's versions.cmake. The BLAS/LAPACK side libraries
# would be compiled by default when Eigen is the top-level project.
recipe_eigen() {
    local ver=8a1083e9bf41b91fdea6546681f806154efdc25a
    local src="$SRC_DIR/eigen-$ver"
    download_and_extract "https://gitlab.com/libeigen/eigen/-/archive/$ver/eigen-$ver.tar.gz" "$src"
    cmake_android "$src" "$BUILD_DIR_BASE/eigen-$ARCH" \
        -DEIGEN_BUILD_DOC=OFF -DEIGEN_BUILD_TESTING=OFF \
        -DEIGEN_BUILD_BLAS=OFF -DEIGEN_BUILD_LAPACK=OFF -DEIGEN_BUILD_DEMOS=OFF
}
