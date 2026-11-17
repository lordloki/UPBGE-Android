#!/usr/bin/env bash
# deps/recipes/opensubdiv.sh
#
# Source: https://github.com/PixarAnimationStudios/OpenSubdiv/archive/refs/tags/v3_6_0.tar.gz
# Reference: Wanderson's build_files/android/deps/build.sh
# 
#
# STATUS: stub. The skeleton below will fetch and call cmake_android; you
#         likely need to add feature toggles, patch steps, or post-install
#         fixes. See the README in this directory for the contract.
recipe_opensubdiv() {
    local src="$SRC_DIR/opensubdiv"
    if [ ! -d "$src" ]; then
        download_and_extract "https://github.com/PixarAnimationStudios/OpenSubdiv/archive/refs/tags/v3_6_0.tar.gz" "$src"
    fi
    # If a patch exists, apply it now:
    #   patch -d "$src" -p1 < "$UPBGE_ANDROID_ROOT/build_files/android/patches/opensubdiv_android.diff"
    cmake_android "$src" "$BUILD_DIR_BASE/opensubdiv-$ARCH"
}
