#!/usr/bin/env bash
# deps/recipes/boost.sh
#
# Source: https://boostorg.jfrog.io/artifactory/main/release/1.84.0/source/boost_1_84_0.tar.gz
# Reference: Wanderson's build_files/android/deps/build.sh
# Bootstrap with --without-{python,mpi,graph,log,test,wave}. Build only the static libraries: filesystem, system, thread, regex, date_time, iostreams, program_options.
#
# STATUS: stub. The skeleton below will fetch and call cmake_android; you
#         likely need to add feature toggles, patch steps, or post-install
#         fixes. See the README in this directory for the contract.
recipe_boost() {
    local src="$SRC_DIR/boost"
    if [ ! -d "$src" ]; then
        download_and_extract "https://boostorg.jfrog.io/artifactory/main/release/1.84.0/source/boost_1_84_0.tar.gz" "$src"
    fi
    # If a patch exists, apply it now:
    #   patch -d "$src" -p1 < "$UPBGE_ANDROID_ROOT/build_files/android/patches/boost_android.diff"
    cmake_android "$src" "$BUILD_DIR_BASE/boost-$ARCH"
}
