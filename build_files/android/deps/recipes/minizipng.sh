#!/usr/bin/env bash
# minizip-ng: required by OpenColorIO (.ocioz archives). Only zlib is enabled,
# as Blender does; every other codec would add link-time dependencies.
recipe_minizipng() {
    local ver=4.2.2
    local src="$SRC_DIR/minizip-ng-$ver"
    download_and_extract "https://github.com/zlib-ng/minizip-ng/archive/$ver.tar.gz" "$src"
    cmake_android "$src" "$BUILD_DIR_BASE/minizipng-$ARCH" \
        -DMZ_FETCH_LIBS=OFF -DMZ_LIBCOMP=OFF -DMZ_PKCRYPT=OFF -DMZ_WZAES=OFF \
        -DMZ_OPENSSL=OFF -DMZ_LIBBSD=OFF -DMZ_PPMD=OFF -DMZ_LZMA=OFF \
        -DMZ_ZSTD=OFF -DMZ_BZIP2=OFF -DMZ_ICONV=OFF \
        -DMZ_ZLIB=ON -DMZ_ZLIB_FLAVOR=zlib \
        -DZLIB_LIBRARY="$DEPS_PREFIX/lib/libz.a" \
        -DZLIB_INCLUDE_DIR="$DEPS_PREFIX/include"
}
