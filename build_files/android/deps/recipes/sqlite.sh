#!/usr/bin/env bash
# SQLite amalgamation, built as a static library with the modules used by Python.
recipe_sqlite() {
    local ver=3450100 src="$SRC_DIR/sqlite"
    download_and_extract "https://www.sqlite.org/2024/sqlite-autoconf-$ver.tar.gz" "$src"
    autotools_android "$src" "$BUILD_DIR_BASE/sqlite-$ARCH" \
        --enable-threadsafe --enable-fts4 --enable-fts5 --enable-json1 \
        --enable-rtree --disable-readline --disable-editline
}
