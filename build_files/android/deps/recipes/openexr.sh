#!/usr/bin/env bash
# deps/recipes/openexr.sh
#
# Source: https://github.com/AcademySoftwareFoundation/openexr/archive/refs/tags/v3.2.4.tar.gz
# Reference: Wanderson's build_files/android/deps/build.sh
# Expects zlib + libdeflate. Use Imath from the same tag.
#
# STATUS: stub. The skeleton below will fetch and call cmake_android; you
#         likely need to add feature toggles, patch steps, or post-install
#         fixes. See the README in this directory for the contract.
recipe_openexr() {
    local src="$SRC_DIR/openexr"
    if [ ! -d "$src" ]; then
        download_and_extract "https://github.com/AcademySoftwareFoundation/openexr/archive/refs/tags/v3.2.4.tar.gz" "$src"
    fi
    # If a patch exists, apply it now:
    #   patch -d "$src" -p1 < "$UPBGE_ANDROID_ROOT/build_files/android/patches/openexr_android.diff"
    cmake_android "$src" "$BUILD_DIR_BASE/openexr-$ARCH"
}
