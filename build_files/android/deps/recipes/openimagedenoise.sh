#!/usr/bin/env bash
# deps/recipes/openimagedenoise.sh
#
# Source: https://github.com/OpenImageDenoise/oidn/archive/refs/tags/v2.2.2.tar.gz
# Reference: Wanderson's build_files/android/deps/build.sh
# Apply build_files/android/patches/oidn_android.diff before configuring.
#
# STATUS: stub. The skeleton below will fetch and call cmake_android; you
#         likely need to add feature toggles, patch steps, or post-install
#         fixes. See the README in this directory for the contract.
recipe_openimagedenoise() {
    local src="$SRC_DIR/openimagedenoise"
    if [ ! -d "$src" ]; then
        download_and_extract "https://github.com/OpenImageDenoise/oidn/archive/refs/tags/v2.2.2.tar.gz" "$src"
    fi
    # If a patch exists, apply it now:
    #   patch -d "$src" -p1 < "$UPBGE_ANDROID_ROOT/build_files/android/patches/openimagedenoise_android.diff"
    cmake_android "$src" "$BUILD_DIR_BASE/openimagedenoise-$ARCH"
}
