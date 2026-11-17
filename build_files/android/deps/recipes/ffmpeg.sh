#!/usr/bin/env bash
# deps/recipes/ffmpeg.sh
#
# FFmpeg is huge and has many configure knobs. This recipe builds the minimum
# UPBGE needs: H.264, AAC, MP3, Theora, Vorbis decoders, no encoders, no
# filters, no programs. Wanderson enables a slightly larger set; if you need
# more (e.g. H.265), add the corresponding --enable-decoder.
recipe_ffmpeg() {
    local ver="6.1.1"
    local src="$SRC_DIR/ffmpeg-$ver"
    if [ ! -d "$src" ]; then
        download_and_extract \
            "https://ffmpeg.org/releases/ffmpeg-$ver.tar.xz" \
            "$src"
    fi

    local api_level="${ANDROID_PLATFORM#android-}"
    local prefix="$DEPS_PREFIX"
    local bld="$BUILD_DIR_BASE/ffmpeg-$ARCH"
    mkdir -p "$bld"

    (
        cd "$src"
        export PATH="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH"
        export CC="$TRIPLET$api_level-clang"
        export CXX="$TRIPLET$api_level-clang++"
        export AR=llvm-ar RANLIB=llvm-ranlib STRIP=llvm-strip
        export CFLAGS="-fPIC -D__ANDROID_API__=$api_level"
        export LDFLAGS="-fPIC"

        ./configure \
            --prefix="$prefix" \
            --enable-static --disable-shared \
            --disable-programs --disable-doc \
            --disable-encoders --disable-muxers --disable-devices \
            --disable-network \
            --enable-decoder=h264,aac,mp3,theora,vorbis,vp8,vp9,opus,flac \
            --enable-demuxer=mov,matroska,mp3,ogg,flac \
            --enable-parser=h264,aac,opus,vp9 \
            --enable-protocol=file \
            --enable-cross-compile \
            --target-os=android \
            --arch="${ARCH%-*}" \
            --extra-cflags="$CFLAGS" \
            --extra-ldflags="$LDFLAGS" \
            --pkg-config-flags="--static"

        make -j"$JOBS"
        make install
    )
}
