#!/usr/bin/env bash
# Build the gettext runtime for Android; host-side gettext tools are not needed.
recipe_gettext() {
    local ver="0.22.5"
    local src="$SRC_DIR/gettext-$ver/gettext-runtime"
    download_and_extract "https://ftp.gnu.org/pub/gnu/gettext/gettext-$ver.tar.gz" "$SRC_DIR/gettext-$ver"
    [ -f "$src/configure" ] || {
        echo "gettext runtime configure script not found: $src/configure" >&2
        return 1
    }
    autotools_android "$src" "$BUILD_DIR_BASE/gettext-$ARCH" \
        --disable-java --disable-native-java --disable-csharp --disable-openmp \
        --disable-rpath --without-emacs --without-lispdir
}
