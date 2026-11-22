#!/usr/bin/env bash
# libvorbis depends on libogg; the build order in deps/build.sh guarantees it exists.
recipe_vorbis() {
    local ver=1.3.7
    local src="$SRC_DIR/libvorbis-$ver"
    download_and_extract "https://downloads.xiph.org/releases/vorbis/libvorbis-$ver.tar.gz" "$src"
    autotools_android "$src" "$BUILD_DIR_BASE/vorbis-$ARCH" \
        --with-ogg="$DEPS_PREFIX" --disable-examples --disable-docs
}
