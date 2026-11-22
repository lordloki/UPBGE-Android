#!/usr/bin/env bash
# OpenImageIO: a hard requirement of Blender >= 3.6 (all image formats go
# through it). Static, plugins embedded, only the formats the player can use.
# SIMD is left to auto-detection: OIIO's simd.h maps to NEON on aarch64.
# WebP stays off: Blender reads/writes WebP itself (imbuf/format_webp.cc), and
# the static OIIO config would reference WebP:: targets it never imports.
recipe_openimageio() {
    local ver=v3.1.16.0
    local src="$SRC_DIR/OpenImageIO-$ver"
    download_and_extract "https://github.com/AcademySoftwareFoundation/OpenImageIO/archive/refs/tags/$ver.tar.gz" "$src"
    cmake_android "$src" "$BUILD_DIR_BASE/openimageio-$ARCH" \
        -DLINKSTATIC=ON -DSTOP_ON_WARNING=OFF \
        -DOpenImageIO_BUILD_MISSING_DEPS="" \
        -DOIIO_BUILD_TOOLS=OFF -DOIIO_BUILD_TESTS=OFF \
        -DBUILD_DOCS=OFF -DINSTALL_DOCS=OFF -DINSTALL_FONTS=OFF \
        -DUSE_PYTHON=OFF -DUSE_FREETYPE=OFF -DUSE_OPENJPEG=OFF -DUSE_OPENJPH=OFF \
        -DUSE_FFMPEG=OFF -DUSE_LIBHEIF=OFF -DUSE_LIBRAW=OFF -DUSE_JXL=OFF \
        -DUSE_TBB=OFF -DUSE_GIF=OFF -DUSE_PTEX=OFF -DUSE_OPENVDB=OFF \
        -DUSE_DCMTK=OFF -DUSE_QT=OFF -DUSE_OPENCV=OFF -DUSE_NUKE=OFF \
        -DUSE_WEBP=OFF -DUSE_OPENCOLORIO=ON \
        -DUSE_EXTERNAL_PUGIXML=OFF \
        -DImath_ROOT="$DEPS_PREFIX" -DOpenEXR_ROOT="$DEPS_PREFIX" \
        -DOpenColorIO_ROOT="$DEPS_PREFIX" -DRobinmap_ROOT="$DEPS_PREFIX" \
        -Dfmt_ROOT="$DEPS_PREFIX" \
        -Dlibjpeg-turbo_ROOT="$DEPS_PREFIX" \
        -DZLIB_LIBRARY="$DEPS_PREFIX/lib/libz.a" \
        -DZLIB_INCLUDE_DIR="$DEPS_PREFIX/include"
}
