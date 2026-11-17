#!/usr/bin/env bash
# deps/recipes/sdl2.sh
#
# Source: https://github.com/libsdl-org/SDL/releases/download/release-2.30.5/SDL2-2.30.5.tar.gz
# Reference: Wanderson's build_files/android/deps/build.sh
# 
#
# STATUS: stub. The skeleton below will fetch and call cmake_android; you
#         likely need to add feature toggles, patch steps, or post-install
#         fixes. See the README in this directory for the contract.
recipe_sdl2() {
    local src="$SRC_DIR/sdl2"
    if [ ! -d "$src" ]; then
        download_and_extract "https://github.com/libsdl-org/SDL/releases/download/release-2.30.5/SDL2-2.30.5.tar.gz" "$src"
    fi
    # If a patch exists, apply it now:
    #   patch -d "$src" -p1 < "$UPBGE_ANDROID_ROOT/build_files/android/patches/sdl2_android.diff"
    cmake_android "$src" "$BUILD_DIR_BASE/sdl2-$ARCH"
}
