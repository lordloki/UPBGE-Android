#!/usr/bin/env bash
# deps/recipes/materialx.sh
#
# Source: https://github.com/AcademySoftwareFoundation/MaterialX/archive/refs/tags/v1.39.1.tar.gz
# Reference: Wanderson's build_files/android/deps/build.sh
# Build the C++ core only; skip the shader generators that need Python at configure time.
#
# STATUS: stub. The skeleton below will fetch and call cmake_android; you
#         likely need to add feature toggles, patch steps, or post-install
#         fixes. See the README in this directory for the contract.
recipe_materialx() {
    local src="$SRC_DIR/materialx"
    if [ ! -d "$src" ]; then
        download_and_extract "https://github.com/AcademySoftwareFoundation/MaterialX/archive/refs/tags/v1.39.1.tar.gz" "$src"
    fi
    # If a patch exists, apply it now:
    #   patch -d "$src" -p1 < "$UPBGE_ANDROID_ROOT/build_files/android/patches/materialx_android.diff"
    cmake_android "$src" "$BUILD_DIR_BASE/materialx-$ARCH"
}
