#!/usr/bin/env bash
# deps/recipes/fftw3.sh
#
# Source: https://www.fftw.org/fftw-3.3.10.tar.gz
# Reference: Wanderson's build_files/android/deps/build.sh
# 
#
# STATUS: stub. The skeleton below will fetch and call cmake_android; you
#         likely need to add feature toggles, patch steps, or post-install
#         fixes. See the README in this directory for the contract.
recipe_fftw3() {
    local src="$SRC_DIR/fftw3"
    if [ ! -d "$src" ]; then
        download_and_extract "https://www.fftw.org/fftw-3.3.10.tar.gz" "$src"
    fi
    # If a patch exists, apply it now:
    #   patch -d "$src" -p1 < "$UPBGE_ANDROID_ROOT/build_files/android/patches/fftw3_android.diff"
    cmake_android "$src" "$BUILD_DIR_BASE/fftw3-$ARCH"
}
