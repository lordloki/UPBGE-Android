#!/usr/bin/env bash
# Boost.Build is not a CMake project. Build the subset used by Blender/UPBGE.
recipe_boost() {
    local ver=1.84.0 src="$SRC_DIR/boost_1_84_0"
    download_and_extract "https://archives.boost.io/release/$ver/source/boost_1_84_0.tar.gz" "$src"
    ( cd "$src"
      # b2 itself is a host program: let bootstrap pick the host compiler
      # (gcc on every supported distro) instead of requiring an unversioned
      # `clang`, which openSUSE only provides through update-alternatives.
      ./bootstrap.sh --without-libraries=python,mpi,graph,log,wave,test
      cat > user-config.jam <<EOF
using clang : android : $ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$NDK_HOST_OS_TAG/bin/${TRIPLET}${ANDROID_PLATFORM#android-}-clang++ : <archiver>$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$NDK_HOST_OS_TAG/bin/llvm-ar <ranlib>$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$NDK_HOST_OS_TAG/bin/llvm-ranlib <cxxflags>-fPIC <cxxflags>-std=c++17 <compileflags>-D__ANDROID_API__=${ANDROID_PLATFORM#android-} <compileflags>--target=$TRIPLET${ANDROID_PLATFORM#android-} <linkflags>--target=$TRIPLET${ANDROID_PLATFORM#android-} ;
EOF
      ./b2 -j"$JOBS" toolset=clang-android target-os=android architecture=arm address-model=64 \
        variant=release link=static threading=multi runtime-link=shared \
        --user-config=user-config.jam --prefix="$DEPS_PREFIX" --libdir="$DEPS_PREFIX/lib" \
        -sNO_BZIP2=1 -sNO_LZMA=1 -sNO_ZSTD=1 \
        --with-filesystem --with-system --with-thread --with-regex \
        --with-date_time --with-iostreams --with-program_options install
    )
}
