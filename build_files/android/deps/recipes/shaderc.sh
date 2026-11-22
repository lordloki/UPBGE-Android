#!/usr/bin/env bash
# shaderc requires matching glslang and SPIRV-Tools source trees. Its own
# DEPS sync script resolves the revisions pinned by this shaderc release
# (version pinned to UPBGE's versions.cmake). glslang and SPIRV-Tools are built
# as sub-projects and end up inside libshaderc_combined.a.
recipe_shaderc() {
    local ver=v2025.4 src="$SRC_DIR/shaderc-v2025.4"
    download_and_extract "https://github.com/google/shaderc/archive/refs/tags/$ver.tar.gz" "$src"
    if [ -x "$src/utils/git-sync-deps" ]; then
        ( cd "$src" && python3 utils/git-sync-deps )
    fi
    cmake_android "$src" "$BUILD_DIR_BASE/shaderc-$ARCH" \
        -DSHADERC_SKIP_TESTS=ON -DSHADERC_SKIP_EXAMPLES=ON \
        -DSHADERC_SKIP_COPYRIGHT_CHECK=ON -DSHADERC_ENABLE_WGSL_OUTPUT=OFF \
        -DSHADERC_SKIP_EXECUTABLES=ON -DSHADERC_ENABLE_WERROR_COMPILE=OFF \
        -DSPIRV_SKIP_TESTS=ON -DSPIRV_SKIP_EXECUTABLES=ON \
        -DBUILD_SHARED_LIBS=OFF
    # libshaderc (and the bundled SPIRV-Tools) always build a shared variant
    # too; Blender links shaderc_combined, so keep the .so out of the prefix.
    rm -f "$DEPS_PREFIX"/lib/libshaderc_shared.so* "$DEPS_PREFIX"/lib/libSPIRV-Tools-shared.so
    [ -f "$DEPS_PREFIX/lib/libshaderc_combined.a" ] || {
        echo "shaderc did not install libshaderc_combined.a" >&2
        return 1
    }
    # platform_unix.cmake asks pkg-config for "shaderc", whose .pc names the
    # shared library removed above. Point it at the combined archive.
    cp -f "$DEPS_PREFIX/lib/pkgconfig/shaderc_combined.pc" \
          "$DEPS_PREFIX/lib/pkgconfig/shaderc.pc"
}
