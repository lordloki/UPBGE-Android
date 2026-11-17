#!/usr/bin/env bash
# deps/recipes/tbb.sh
#
# Source: https://github.com/oneapi-src/oneTBB/archive/refs/tags/v2021.11.0.tar.gz
# Reference: Wanderson's build_files/android/deps/build.sh
# 
#
# STATUS: stub. The skeleton below will fetch and call cmake_android; you
#         likely need to add feature toggles, patch steps, or post-install
#         fixes. See the README in this directory for the contract.
recipe_tbb() {
    local src="$SRC_DIR/tbb"
    if [ ! -d "$src" ]; then
        download_and_extract "https://github.com/oneapi-src/oneTBB/archive/refs/tags/v2021.11.0.tar.gz" "$src"
    fi
    # If a patch exists, apply it now:
    #   patch -d "$src" -p1 < "$UPBGE_ANDROID_ROOT/build_files/android/patches/tbb_android.diff"
    cmake_android "$src" "$BUILD_DIR_BASE/tbb-$ARCH"
}
