#!/usr/bin/env bash
# deps/recipes/vulkan_headers.sh
recipe_vulkan_headers() {
    local ver="v1.3.280"
    local src="$SRC_DIR/Vulkan-Headers-$ver"
    download_and_extract \
        "https://github.com/KhronosGroup/Vulkan-Headers/archive/refs/tags/$ver.tar.gz" \
        "$src"
    # Headers-only install, no toolchain needed.
    cmake_android "$src" "$BUILD_DIR_BASE/vulkan_headers-$ARCH" \
        -DVULKAN_HEADERS_INSTALL=ON
}
