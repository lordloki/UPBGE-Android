#!/usr/bin/env bash
# deps/recipes/libwebp.sh
#
# Source: https://github.com/webmproject/libwebp/archive/refs/tags/v1.3.2.tar.gz
# Reference: Wanderson's build_files/android/deps/build.sh
# 
#
# STATUS: stub. The skeleton below will fetch and call cmake_android; you
#         likely need to add feature toggles, patch steps, or post-install
#         fixes. See the README in this directory for the contract.
recipe_libwebp() {
    local src="$SRC_DIR/libwebp"
    if [ ! -d "$src" ]; then
        download_and_extract "https://github.com/webmproject/libwebp/archive/refs/tags/v1.3.2.tar.gz" "$src"
    fi
    # If a patch exists, apply it now:
    #   patch -d "$src" -p1 < "$UPBGE_ANDROID_ROOT/build_files/android/patches/libwebp_android.diff"
    cmake_android "$src" "$BUILD_DIR_BASE/libwebp-$ARCH"
}
