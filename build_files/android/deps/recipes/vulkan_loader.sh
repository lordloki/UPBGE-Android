#!/usr/bin/env bash
# deps/recipes/vulkan_loader.sh
#
# The loader discovers the system ICD through Android's libvulkan.so. We need
# the loader headers and a stub for find_package(Vulkan) at configure time.
recipe_vulkan_loader() {
    local ver="v1.3.280"
    local src="$SRC_DIR/Vulkan-Loader-$ver"
    if [ ! -d "$src" ]; then
        download_and_extract \
            "https://github.com/KhronosGroup/Vulkan-Loader/archive/refs/tags/$ver.tar.gz" \
            "$src"
    fi
    # The actual ICD lives in /system/lib*/libvulkan.so on the device; we only
    # need the loader's headers and cmake config so UPBGE's find_package(Vulkan)
    # succeeds. Skip building the loader itself.
    cmake_android "$src" "$BUILD_DIR_BASE/vulkan_loader-$ARCH" \
        -DBUILD_TESTS=OFF \
        -DBUILD_WSI_XCB_SUPPORT=OFF \
        -DBUILD_WSI_XLIB_SUPPORT=OFF \
        -DBUILD_WSI_WAYLAND_SUPPORT=OFF \
        -DBUILD_WSI_HEADLESS_SUPPORT=OFF \
        -DUSE_GAS=OFF
    # If the loader .so didn't build (Android backend is incomplete in upstream
    # loader), fall back to a hand-rolled stub.
    if [ ! -f "$DEPS_PREFIX/lib/libvulkan.so" ]; then
        echo "  stubbing libvulkan.so (will use system libvulkan at runtime)"
        echo "INPUT(-lvulkan)" > "$DEPS_PREFIX/lib/libvulkan.so"
    fi
}
