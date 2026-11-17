#!/usr/bin/env bash
# deps/recipes/ceres.sh
#
# Source: https://github.com/ceres-solver/ceres-solver/archive/refs/tags/2.2.0.tar.gz
# Reference: Wanderson's build_files/android/deps/build.sh
# Drop TBB if WITH_TBB=OFF in player_only; use std::thread backend.
#
# STATUS: stub. The skeleton below will fetch and call cmake_android; you
#         likely need to add feature toggles, patch steps, or post-install
#         fixes. See the README in this directory for the contract.
recipe_ceres() {
    local src="$SRC_DIR/ceres"
    if [ ! -d "$src" ]; then
        download_and_extract "https://github.com/ceres-solver/ceres-solver/archive/refs/tags/2.2.0.tar.gz" "$src"
    fi
    # If a patch exists, apply it now:
    #   patch -d "$src" -p1 < "$UPBGE_ANDROID_ROOT/build_files/android/patches/ceres_android.diff"
    cmake_android "$src" "$BUILD_DIR_BASE/ceres-$ARCH"
}
