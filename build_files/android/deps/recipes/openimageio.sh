#!/usr/bin/env bash
# deps/recipes/openimageio.sh
#
# Source: https://github.com/OpenImageIO/oiio/archive/refs/tags/v2.5.12.0.tar.gz
# Reference: Wanderson's build_files/android/deps/build.sh
# Heavy. Requires boost, libtiff, openexr, libjpeg, libpng. Wanderson enables only the readers needed by Blender.
#
# STATUS: stub. The skeleton below will fetch and call cmake_android; you
#         likely need to add feature toggles, patch steps, or post-install
#         fixes. See the README in this directory for the contract.
recipe_openimageio() {
    local src="$SRC_DIR/openimageio"
    if [ ! -d "$src" ]; then
        download_and_extract "https://github.com/OpenImageIO/oiio/archive/refs/tags/v2.5.12.0.tar.gz" "$src"
    fi
    # If a patch exists, apply it now:
    #   patch -d "$src" -p1 < "$UPBGE_ANDROID_ROOT/build_files/android/patches/openimageio_android.diff"
    cmake_android "$src" "$BUILD_DIR_BASE/openimageio-$ARCH"
}
