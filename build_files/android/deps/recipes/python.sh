#!/usr/bin/env bash
# deps/recipes/python.sh
#
# Cross-compile CPython for Android. This is the trickiest recipe because
# Python needs to be built twice: once on the host to produce the
# `Parser/pgen` and other build tools, then again for the target.
#
# Wanderson's deps/build.sh handles this by running CPython's own ./configure
# with the NDK compiler and a host-tools build step. This recipe follows the
# same shape, condensed.
recipe_python() {
    local ver="3.11.9"
    local src="$SRC_DIR/Python-$ver"
    if [ ! -d "$src" ]; then
        download_and_extract \
            "https://www.python.org/ftp/python/$ver/Python-$ver.tgz" \
            "$src"
    fi

    # 1. Host build — produces `pgen` and ` Programs/_freeze_module`.
    local host_bld="$BUILD_DIR_BASE/python-host"
    mkdir -p "$host_bld"
    (
        cd "$src"
        CC="$HOST_CC" CXX="$HOST_CXX" ./configure \
            --prefix="$host_bld" \
            --without-pymalloc \
            --without-ensurepip \
            ac_cv_file__dev_ptmx=yes ac_cv_file__dev_ptc=no
        make -j"$JOBS" python Parser/pgen Programs/_freeze_module
        make install
    )

    # 2. Cross build — uses the host pgen and _freeze_module.
    local bld="$BUILD_DIR_BASE/python-$ARCH"
    mkdir -p "$bld"
    local api_level="${ANDROID_PLATFORM#android-}"
    (
        cd "$src"
        # CPython has no CMake; use autotools with the NDK compiler directly.
        export PATH="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin:$PATH"
        export CC="$TRIPLET$api_level-clang"
        export CXX="$TRIPLET$api_level-clang++"
        export AR=llvm-ar RANLIB=llvm-ranlib READELF=llvm-readelf
        export CFLAGS="-fPIC -D__ANDROID_API__=$api_level"
        export LDFLAGS="-fPIC"
        # Use the host pgen so we don't try to run target binaries.
        ./configure \
            --host="$TRIPLET" \
            --build="$(gcc -dumpmachine 2>/dev/null || echo x86_64-linux-gnu)" \
            --prefix="$DEPS_PREFIX" \
            --enable-shared=no \
            --without-pymalloc \
            --without-ensurepip \
            --with-openssl="$DEPS_PREFIX" \
            --with-system-ffi \
            ac_cv_file__dev_ptmx=yes ac_cv_file__dev_ptc=no \
            ac_cv_buggy_getaddrinfo=no
        make -j"$JOBS" HOST_RUNNER="$host_bld/bin/python3" \
            HOST_PGEN="$host_bld/bin/pgen" || true
        make install
    )

    # 3. Install the stdlib into the deps prefix's lib/python3.11/ tree
    #    (this is what package_player.sh zips into blender_runtime.zip).
    if [ ! -d "$DEPS_PREFIX/lib/python3.11" ]; then
        echo "  WARN: $DEPS_PREFIX/lib/python3.11 missing after install"
    fi
}
