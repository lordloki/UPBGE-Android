#!/usr/bin/env bash
# deps/recipes/alembic.sh
#
# Source: https://github.com/alembic/alembic/archive/refs/tags/1.8.6.tar.gz
# Reference: Wanderson's build_files/android/deps/build.sh
# Requires ilmbase/openexr headers + hdf5.
#
# STATUS: stub. The skeleton below will fetch and call cmake_android; you
#         likely need to add feature toggles, patch steps, or post-install
#         fixes. See the README in this directory for the contract.
recipe_alembic() {
    local src="$SRC_DIR/alembic"
    if [ ! -d "$src" ]; then
        download_and_extract "https://github.com/alembic/alembic/archive/refs/tags/1.8.6.tar.gz" "$src"
    fi
    # If a patch exists, apply it now:
    #   patch -d "$src" -p1 < "$UPBGE_ANDROID_ROOT/build_files/android/patches/alembic_android.diff"
    cmake_android "$src" "$BUILD_DIR_BASE/alembic-$ARCH"
}
