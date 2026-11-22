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

    # Without LIBDIR, platform_unix.cmake finds Vulkan with pkg-config. The
    # Khronos loader would install this file; the NDK stub does not.
    local hdr="$DEPS_PREFIX/include/vulkan/vulkan_core.h"
    local patch
    patch="$(sed -n 's/^#define VK_HEADER_VERSION \([0-9]*\).*/\1/p' "$hdr" 2>/dev/null)"
    if [ -z "$patch" ]; then
        echo "vulkan_loader: $hdr missing (build vulkan_headers first)" >&2
        return 1
    fi
    mkdir -p "$DEPS_PREFIX/lib/pkgconfig"
    cat > "$DEPS_PREFIX/lib/pkgconfig/vulkan.pc" <<EOF
prefix=$DEPS_PREFIX
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: Vulkan-Loader
Description: Android system Vulkan loader (NDK link stub)
Version: 1.4.$patch
Libs: -L\${libdir} -lvulkan
Cflags: -I\${includedir}
EOF
}
