#!/usr/bin/env bash
# deps/recipes/xml2.sh
#
# Source: https://gitlab.gnome.org/GNOME/libxml2/-/archive/v2.12.5/libxml2-v2.12.5.tar.gz
# Reference: Wanderson's build_files/android/deps/build.sh
# 
#
# STATUS: stub. The skeleton below will fetch and call cmake_android; you
#         likely need to add feature toggles, patch steps, or post-install
#         fixes. See the README in this directory for the contract.
recipe_xml2() {
    local src="$SRC_DIR/xml2"
    if [ ! -d "$src" ]; then
        download_and_extract "https://gitlab.gnome.org/GNOME/libxml2/-/archive/v2.12.5/libxml2-v2.12.5.tar.gz" "$src"
    fi
    # If a patch exists, apply it now:
    #   patch -d "$src" -p1 < "$UPBGE_ANDROID_ROOT/build_files/android/patches/xml2_android.diff"
    cmake_android "$src" "$BUILD_DIR_BASE/xml2-$ARCH"
}
