#!/usr/bin/env bash
# shaderc requires matching glslang and SPIRV-Tools source trees. Its own
# DEPS sync script resolves the revisions pinned by this shaderc release.
recipe_shaderc() {
    local ver=v2024.1 src="$SRC_DIR/shaderc-v2024.1"
    download_and_extract "https://github.com/google/shaderc/archive/refs/tags/$ver.tar.gz" "$src"
    if [ -x "$src/utils/git-sync-deps" ]; then
        ( cd "$src" && python3 utils/git-sync-deps )
    fi
    cmake_android "$src" "$BUILD_DIR_BASE/shaderc-$ARCH" \
        -DSHADERC_SKIP_TESTS=ON -DSHADERC_SKIP_EXAMPLES=ON \
        -DSHADERC_SKIP_COPYRIGHT_CHECK=ON -DSHADERC_ENABLE_WGSL_OUTPUT=OFF \
        -DSPIRV_SKIP_TESTS=ON -DSPIRV_SKIP_EXECUTABLES=ON \
        -DBUILD_SHARED_LIBS=OFF
}
