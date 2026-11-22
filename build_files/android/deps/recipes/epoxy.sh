#!/usr/bin/env bash
# libepoxy: Blender's platform_unix requires Epoxy unconditionally, even with
# only the Vulkan backend. Meson project (as in Blender's build_environment);
# EGL only, it dlopen()s libEGL/libGLESv2 at runtime. Needs host meson + ninja.
recipe_epoxy() {
    local ver=1.5.10
    local src="$SRC_DIR/libepoxy-$ver"
    local bld="$BUILD_DIR_BASE/epoxy-$ARCH"
    local api="${ANDROID_PLATFORM#android-}"
    local ndk_bin="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$NDK_HOST_OS_TAG/bin"
    command -v meson >/dev/null || { echo "meson not found (run make setup-host)" >&2; return 1; }
    download_and_extract "https://github.com/anholt/libepoxy/archive/refs/tags/$ver.tar.gz" "$src"
    rm -rf "$bld"
    mkdir -p "$bld"
    cat > "$bld/android-cross.ini" <<EOF
[binaries]
c = '$ndk_bin/${TRIPLET}${api}-clang'
cpp = '$ndk_bin/${TRIPLET}${api}-clang++'
ar = '$ndk_bin/llvm-ar'
strip = '$ndk_bin/llvm-strip'
pkg-config = 'pkg-config'

[host_machine]
system = 'android'
cpu_family = 'aarch64'
cpu = 'armv8-a'
endian = 'little'
EOF
    meson setup "$bld/build" "$src" \
        --cross-file "$bld/android-cross.ini" \
        --prefix "$DEPS_PREFIX" --libdir lib \
        --buildtype release --default-library static \
        -Dglx=no -Degl=yes -Dx11=false -Dtests=false -Ddocs=false
    ninja -C "$bld/build" -j"$JOBS"
    ninja -C "$bld/build" install
}
