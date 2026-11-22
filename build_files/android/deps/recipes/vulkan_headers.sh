#!/usr/bin/env bash
# deps/recipes/vulkan_headers.sh
recipe_vulkan_headers() {
    local ver="v1.4.341"  # UPBGE versions.cmake
    local src="$SRC_DIR/Vulkan-Headers-$ver"
    download_and_extract \
        "https://github.com/KhronosGroup/Vulkan-Headers/archive/refs/tags/$ver.tar.gz" \
        "$src"
    # Headers-only install, no toolchain needed.
    # The C++20 module needs CMake module scanning; Blender uses the C headers.
    cmake_android "$src" "$BUILD_DIR_BASE/vulkan_headers-$ARCH" \
        -DVULKAN_HEADERS_ENABLE_INSTALL=ON -DVULKAN_HEADERS_ENABLE_TESTS=OFF \
        -DVULKAN_HEADERS_ENABLE_MODULE=OFF
}
