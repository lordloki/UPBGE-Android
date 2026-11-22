#!/usr/bin/env bash
# Opus uses Autotools and supports Android's ARMv8 NEON implementation.
recipe_opus() {
    local ver=1.5.1
    local src="$SRC_DIR/opus-$ver"
    download_and_extract "https://github.com/xiph/opus/releases/download/v$ver/opus-$ver.tar.gz" "$src"
    autotools_android "$src" "$BUILD_DIR_BASE/opus-$ARCH" \
        --disable-doc --disable-extra-programs --disable-maintainer-mode
}
