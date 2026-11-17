#!/usr/bin/env bash
# deps/recipes/glew.sh
#
# Source: https://github.com/nigels-com/glew/releases/download/glew-2.2.0/glew-2.2.0.tgz
# Reference: Wanderson's build_files/android/deps/build.sh
# 
#
# STATUS: stub. The skeleton below will fetch and call cmake_android; you
#         likely need to add feature toggles, patch steps, or post-install
#         fixes. See the README in this directory for the contract.
recipe_glew() {
    local src="$SRC_DIR/glew"
    if [ ! -d "$src" ]; then
        download_and_extract "https://github.com/nigels-com/glew/releases/download/glew-2.2.0/glew-2.2.0.tgz" "$src"
    fi
    # If a patch exists, apply it now:
    #   patch -d "$src" -p1 < "$UPBGE_ANDROID_ROOT/build_files/android/patches/glew_android.diff"
    cmake_android "$src" "$BUILD_DIR_BASE/glew-$ARCH"
}
