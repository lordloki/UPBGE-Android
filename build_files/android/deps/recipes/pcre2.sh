#!/usr/bin/env bash
# deps/recipes/pcre2.sh
#
# Source: https://github.com/PCRE2Project/pcre2/archive/refs/tags/pcre2-10.43.tar.gz
# Reference: Wanderson's build_files/android/deps/build.sh
# 
#
# STATUS: stub. The skeleton below will fetch and call cmake_android; you
#         likely need to add feature toggles, patch steps, or post-install
#         fixes. See the README in this directory for the contract.
recipe_pcre2() {
    local src="$SRC_DIR/pcre2"
    if [ ! -d "$src" ]; then
        download_and_extract "https://github.com/PCRE2Project/pcre2/archive/refs/tags/pcre2-10.43.tar.gz" "$src"
    fi
    # If a patch exists, apply it now:
    #   patch -d "$src" -p1 < "$UPBGE_ANDROID_ROOT/build_files/android/patches/pcre2_android.diff"
    cmake_android "$src" "$BUILD_DIR_BASE/pcre2-$ARCH"
}
