#!/usr/bin/env bash
# deps/recipes/sqlite.sh
#
# Source: https://www.sqlite.org/2024/sqlite-autoconf-3450100.tar.gz
# Reference: Wanderson's build_files/android/deps/build.sh
# 
#
# STATUS: stub. The skeleton below will fetch and call cmake_android; you
#         likely need to add feature toggles, patch steps, or post-install
#         fixes. See the README in this directory for the contract.
recipe_sqlite() {
    local src="$SRC_DIR/sqlite"
    if [ ! -d "$src" ]; then
        download_and_extract "https://www.sqlite.org/2024/sqlite-autoconf-3450100.tar.gz" "$src"
    fi
    # If a patch exists, apply it now:
    #   patch -d "$src" -p1 < "$UPBGE_ANDROID_ROOT/build_files/android/patches/sqlite_android.diff"
    cmake_android "$src" "$BUILD_DIR_BASE/sqlite-$ARCH"
}
