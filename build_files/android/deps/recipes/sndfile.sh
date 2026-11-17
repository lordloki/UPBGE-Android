#!/usr/bin/env bash
# deps/recipes/sndfile.sh
#
# Source: https://github.com/libsndfile/libsndfile/releases/download/1.2.2/libsndfile-1.2.2.tar.xz
# Reference: Wanderson's build_files/android/deps/build.sh
# 
#
# STATUS: stub. The skeleton below will fetch and call cmake_android; you
#         likely need to add feature toggles, patch steps, or post-install
#         fixes. See the README in this directory for the contract.
recipe_sndfile() {
    local src="$SRC_DIR/sndfile"
    if [ ! -d "$src" ]; then
        download_and_extract "https://github.com/libsndfile/libsndfile/releases/download/1.2.2/libsndfile-1.2.2.tar.xz" "$src"
    fi
    # If a patch exists, apply it now:
    #   patch -d "$src" -p1 < "$UPBGE_ANDROID_ROOT/build_files/android/patches/sndfile_android.diff"
    cmake_android "$src" "$BUILD_DIR_BASE/sndfile-$ARCH"
}
