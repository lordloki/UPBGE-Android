#!/usr/bin/env bash
# libogg is an Autotools project.
recipe_ogg() {
    local ver=1.3.5 src="$SRC_DIR/libogg-$ver"
    download_and_extract "https://downloads.xiph.org/releases/ogg/libogg-$ver.tar.gz" "$src"
    autotools_android "$src" "$BUILD_DIR_BASE/ogg-$ARCH" --disable-examples --disable-docs
}
