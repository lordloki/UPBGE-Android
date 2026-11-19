#!/usr/bin/env bash
# SDL2 Android backend; native Android activity integration is provided by the APK.
recipe_sdl2() {
    local ver=2.30.5 src="$SRC_DIR/SDL2-$ver"
    download_and_extract "https://github.com/libsdl-org/SDL/releases/download/release-$ver/SDL2-$ver.tar.gz" "$src"
    cmake_android "$src" "$BUILD_DIR_BASE/sdl2-$ARCH" \
        -DSDL_SHARED=OFF -DSDL_STATIC=ON -DSDL_TEST=OFF \
        -DSDL_ATOMIC=ON -DSDL_AUDIO=ON -DSDL_VIDEO=ON -DSDL_RENDER=ON \
        -DSDL_JOYSTICK=ON -DSDL_HAPTIC=ON -DSDL_POWER=ON -DSDL_SENSOR=ON \
        -DSDL_FILESYSTEM=ON -DSDL_LOADSO=ON -DSDL_THREADS=ON
}
