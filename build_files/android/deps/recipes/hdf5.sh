#!/usr/bin/env bash
# deps/recipes/hdf5.sh
#
# Source: https://support.hdfgroup.org/releases/hdf5/v1_14/v1_14_3/downloads/hdf5-1.14.3.tar.gz
# Reference: Wanderson's build_files/android/deps/build.sh
# Required by Alembic when WITH_ALEMBIC_HDF5=ON.
#
# STATUS: stub. The skeleton below will fetch and call cmake_android; you
#         likely need to add feature toggles, patch steps, or post-install
#         fixes. See the README in this directory for the contract.
recipe_hdf5() {
    local src="$SRC_DIR/hdf5"
    if [ ! -d "$src" ]; then
        download_and_extract "https://support.hdfgroup.org/releases/hdf5/v1_14/v1_14_3/downloads/hdf5-1.14.3.tar.gz" "$src"
    fi
    # If a patch exists, apply it now:
    #   patch -d "$src" -p1 < "$UPBGE_ANDROID_ROOT/build_files/android/patches/hdf5_android.diff"
    cmake_android "$src" "$BUILD_DIR_BASE/hdf5-$ARCH"
}
