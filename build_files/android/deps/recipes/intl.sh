#!/usr/bin/env bash
# deps/recipes/intl.sh
#
# Source: https://ftp.gnu.org/pub/gnu/gettext/gettext-0.22.5.tar.gz
# Reference: Wanderson's build_files/android/deps/build.sh
# 
#
# STATUS: stub. The skeleton below will fetch and call cmake_android; you
#         likely need to add feature toggles, patch steps, or post-install
#         fixes. See the README in this directory for the contract.
recipe_intl() {
    local src="$SRC_DIR/intl"
    if [ ! -d "$src" ]; then
        download_and_extract "https://ftp.gnu.org/pub/gnu/gettext/gettext-0.22.5.tar.gz" "$src"
    fi
    # If a patch exists, apply it now:
    #   patch -d "$src" -p1 < "$UPBGE_ANDROID_ROOT/build_files/android/patches/intl_android.diff"
    cmake_android "$src" "$BUILD_DIR_BASE/intl-$ARCH"
}
