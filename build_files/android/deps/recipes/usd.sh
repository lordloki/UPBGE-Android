#!/usr/bin/env bash
# deps/recipes/usd.sh
#
# Source: https://github.com/PixarAnimationStudios/USD/archive/refs/tags/v24.05.tar.gz
# Reference: Wanderson's build_files/android/deps/build.sh
# Huge. Wanderson enables only the Blender-relevant modules. Disable tests, docs, Python bindings except the ones UPBGE calls.
#
# STATUS: stub. The skeleton below will fetch and call cmake_android; you
#         likely need to add feature toggles, patch steps, or post-install
#         fixes. See the README in this directory for the contract.
recipe_usd() {
    local src="$SRC_DIR/usd"
    if [ ! -d "$src" ]; then
        download_and_extract "https://github.com/PixarAnimationStudios/USD/archive/refs/tags/v24.05.tar.gz" "$src"
    fi
    # If a patch exists, apply it now:
    #   patch -d "$src" -p1 < "$UPBGE_ANDROID_ROOT/build_files/android/patches/usd_android.diff"
    cmake_android "$src" "$BUILD_DIR_BASE/usd-$ARCH"
}
