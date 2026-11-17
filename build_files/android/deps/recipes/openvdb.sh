#!/usr/bin/env bash
# deps/recipes/openvdb.sh
#
# Source: https://github.com/AcademySoftwareFoundation/openvdb/archive/refs/tags/v11.0.0.tar.gz
# Reference: Wanderson's build_files/android/deps/build.sh
# Requires boost, tbb, zlib, blosc (drop blosc on Android).
#
# STATUS: stub. The skeleton below will fetch and call cmake_android; you
#         likely need to add feature toggles, patch steps, or post-install
#         fixes. See the README in this directory for the contract.
recipe_openvdb() {
    local src="$SRC_DIR/openvdb"
    if [ ! -d "$src" ]; then
        download_and_extract "https://github.com/AcademySoftwareFoundation/openvdb/archive/refs/tags/v11.0.0.tar.gz" "$src"
    fi
    # If a patch exists, apply it now:
    #   patch -d "$src" -p1 < "$UPBGE_ANDROID_ROOT/build_files/android/patches/openvdb_android.diff"
    cmake_android "$src" "$BUILD_DIR_BASE/openvdb-$ARCH"
}
