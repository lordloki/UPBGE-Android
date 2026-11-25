#!/usr/bin/env bash
# SQLite amalgamation, built as a static library with the modules used by Python.
# Since 3.49 the autoconf bundle uses autosetup: JSON is always built in and
# the old --enable-json1 flag is rejected as an unknown option.
recipe_sqlite() {
    local ver=3510300
    local src="$SRC_DIR/sqlite-$ver"
    download_and_extract "https://www.sqlite.org/2026/sqlite-autoconf-$ver.tar.gz" "$src"
    autotools_android "$src" "$BUILD_DIR_BASE/sqlite-$ARCH" \
        --enable-threadsafe --enable-fts4 --enable-fts5 \
        --enable-rtree --disable-readline --disable-editline
}
