#!/usr/bin/env bash
# deps/recipes/embree.sh
#
# Source: https://github.com/embree/embree/archive/refs/tags/v4.3.1.tar.gz
# Reference: Wanderson's build_files/android/deps/build.sh
# 
#
# STATUS: stub. The skeleton below will fetch and call cmake_android; you
#         likely need to add feature toggles, patch steps, or post-install
#         fixes. See the README in this directory for the contract.
recipe_embree() {
    local src="$SRC_DIR/embree"
    if [ ! -d "$src" ]; then
        download_and_extract "https://github.com/embree/embree/archive/refs/tags/v4.3.1.tar.gz" "$src"
    fi
    # If a patch exists, apply it now:
    #   patch -d "$src" -p1 < "$UPBGE_ANDROID_ROOT/build_files/android/patches/embree_android.diff"
    cmake_android "$src" "$BUILD_DIR_BASE/embree-$ARCH"
}
