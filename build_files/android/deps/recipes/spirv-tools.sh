#!/usr/bin/env bash
# SPIRV-Tools is a required shaderc dependency. The shaderc checkout's
# DEPS file pins the matching SPIRV-Headers revision; fetch it through the
# project's sync script rather than relying on an arbitrary system copy.
recipe_spirv-tools() {
    local ver=v2024.1 src="$SRC_DIR/SPIRV-Tools-v2024.1"
    download_and_extract "https://github.com/KhronosGroup/SPIRV-Tools/archive/refs/tags/$ver.tar.gz" "$src"
    if [ -x "$src/utils/git-sync-deps" ]; then
        ( cd "$src" && python3 utils/git-sync-deps )
    fi
    [ -d "$src/external/spirv-headers/include/spirv" ] || {
        echo "SPIRV-Tools dependency sync did not provide SPIRV-Headers" >&2
        return 1
    }
    cmake_android "$src" "$BUILD_DIR_BASE/spirv-tools-$ARCH" \
        -DSPIRV-Headers_SOURCE_DIR="$src/external/spirv-headers" \
        -DSPIRV_SKIP_TESTS=ON -DSPIRV_SKIP_EXECUTABLES=ON \
        -DSPIRV_WERROR=OFF -DBUILD_SHARED_LIBS=OFF
}
