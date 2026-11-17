#!/usr/bin/env bash
# deps/recipes/gmp.sh
#
# Source: https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz
# Reference: Wanderson's build_files/android/deps/build.sh
# 
#
# STATUS: stub. The skeleton below will fetch and call cmake_android; you
#         likely need to add feature toggles, patch steps, or post-install
#         fixes. See the README in this directory for the contract.
recipe_gmp() {
    local src="$SRC_DIR/gmp"
    if [ ! -d "$src" ]; then
        download_and_extract "https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz" "$src"
    fi
    # If a patch exists, apply it now:
    #   patch -d "$src" -p1 < "$UPBGE_ANDROID_ROOT/build_files/android/patches/gmp_android.diff"
    cmake_android "$src" "$BUILD_DIR_BASE/gmp-$ARCH"
}
