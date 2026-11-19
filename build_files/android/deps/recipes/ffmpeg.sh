#!/usr/bin/env bash
# Minimal static FFmpeg build for UPBGE's player runtime.
recipe_ffmpeg() {
    local ver=6.1.1 src="$SRC_DIR/ffmpeg-6.1.1"
    local api="${ANDROID_PLATFORM#android-}"
    local ndk_bin="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$NDK_HOST_OS_TAG/bin"
    download_and_extract "https://ffmpeg.org/releases/ffmpeg-$ver.tar.xz" "$src"
    mkdir -p "$BUILD_DIR_BASE/ffmpeg-$ARCH"
    (
        cd "$src"
        export PATH="$ndk_bin:$PATH"
        export CC="$ndk_bin/${TRIPLET}${api}-clang"
        export CXX="$ndk_bin/${TRIPLET}${api}-clang++"
        export AR="$ndk_bin/llvm-ar" RANLIB="$ndk_bin/llvm-ranlib"
        export STRIP="$ndk_bin/llvm-strip" NM="$ndk_bin/llvm-nm"
        export CFLAGS="-O2 -fPIC -D__ANDROID_API__=$api -I$DEPS_PREFIX/include"
        export LDFLAGS="-L$DEPS_PREFIX/lib"
        ./configure \
            --prefix="$DEPS_PREFIX" \
            --target-os=android --arch=aarch64 --enable-cross-compile \
            --cc="$CC" --cxx="$CXX" --ar="$AR" --ranlib="$RANLIB" \
            --strip="$STRIP" --nm="$NM" \
            --sysroot="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$NDK_HOST_OS_TAG/sysroot" \
            --enable-pic --enable-static --disable-shared \
            --disable-programs --disable-doc --disable-debug \
            --disable-network --disable-autodetect --disable-avdevice \
            --disable-postproc --disable-encoders --disable-muxers --disable-filters \
            --disable-everything \
            --enable-avcodec --enable-avformat --enable-avutil --enable-swresample \
            --enable-decoder=h264,aac,mp3,theora,vorbis,vp8,vp9,opus,flac \
            --enable-demuxer=mov,matroska,mp3,ogg,flac,wav \
            --enable-parser=h264,aac,mpegaudio,opus,vp9,vorbis \
            --enable-protocol=file \
            --extra-cflags="$CFLAGS" --extra-ldflags="$LDFLAGS" \
            --pkg-config=false
        make -j"$JOBS"
        make install
    )
}
