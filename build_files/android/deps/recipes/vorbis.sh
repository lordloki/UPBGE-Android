#!/usr/bin/env bash
# deps/recipes/vorbis.sh
#
# Source: https://downloads.xiph.org/releases/vorbis/libvorbis-1.3.7.tar.gz
# Reference: Wanderson's build_files/android/deps/build.sh
# 
#
# STATUS: stub. The skeleton below will fetch and call cmake_android; you
#         likely need to add feature toggles, patch steps, or post-install
#         fixes. See the README in this directory for the contract.
recipe_vorbis() {
    local src="$SRC_DIR/vorbis"
    if [ ! -d "$src" ]; then
        download_and_extract "https://downloads.xiph.org/releases/vorbis/libvorbis-1.3.7.tar.gz" "$src"
    fi
    # If a patch exists, apply it now:
    #   patch -d "$src" -p1 < "$UPBGE_ANDROID_ROOT/build_files/android/patches/vorbis_android.diff"
    cmake_android "$src" "$BUILD_DIR_BASE/vorbis-$ARCH"
}
