#!/usr/bin/env bash
# Android provides the Vulkan loader at runtime. The NDK ships a link-time stub;
# copying that stub into the dependency prefix lets CMake resolve Vulkan while
# ensuring the APK uses the device's system loader.
recipe_vulkan_loader() {
    local ndk_sysroot="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$NDK_HOST_OS_TAG/sysroot"
    local api="${ANDROID_PLATFORM#android-}"
    local stub="$ndk_sysroot/usr/lib/$TRIPLET/$api/libvulkan.so"
    if [ ! -f "$stub" ]; then
        stub="$ndk_sysroot/usr/lib/$TRIPLET/libvulkan.so"
    fi
    if [ ! -f "$stub" ]; then
        echo "Android NDK Vulkan link stub not found under $ndk_sysroot" >&2
        return 1
    fi
    mkdir -p "$DEPS_PREFIX/lib"
    cp -f "$stub" "$DEPS_PREFIX/lib/libvulkan.so"
}
