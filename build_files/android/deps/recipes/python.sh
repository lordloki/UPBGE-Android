#!/usr/bin/env bash
# CPython 3.11 cross-build. The host interpreter supplies build-time Python tools;
# target objects are always compiled with the Android NDK.
recipe_python() {
    local ver=3.11.9 mm=3.11 archive="$SRC_DIR/.downloads/Python-3.11.9.tgz"
    local host_src="$SRC_DIR/Python-$ver-host" target_src="$SRC_DIR/Python-$ver-target"
    local host_prefix="$BUILD_DIR_BASE/python-host" target_build="$BUILD_DIR_BASE/python-$ARCH"
    local api="${ANDROID_PLATFORM#android-}"
    local ndk_bin="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$NDK_HOST_OS_TAG/bin"

    mkdir -p "$SRC_DIR/.downloads"
    if [ ! -s "$archive" ]; then
        curl --fail --location --retry 4 --output "$archive.tmp" \
            "https://www.python.org/ftp/python/$ver/Python-$ver.tgz"
        mv "$archive.tmp" "$archive"
    fi
    if [ ! -f "$host_src/configure" ]; then
        rm -rf "$host_src"; mkdir -p "$host_src"
        tar -xzf "$archive" -C "$host_src" --strip-components=1
    fi
    if [ ! -f "$target_src/configure" ]; then
        rm -rf "$target_src"; mkdir -p "$target_src"
        tar -xzf "$archive" -C "$target_src" --strip-components=1
    fi

    if [ ! -x "$host_prefix/bin/python$mm" ]; then
        mkdir -p "$host_prefix"
        ( cd "$host_src"
          ./configure --prefix="$host_prefix" --without-ensurepip --disable-test-modules
          make -j"$JOBS"
          make install
        )
    fi

    mkdir -p "$target_build"
    (
        cd "$target_build"
        export PATH="$ndk_bin:$PATH"
        export CC="$ndk_bin/${TRIPLET}${api}-clang"
        export CXX="$ndk_bin/${TRIPLET}${api}-clang++"
        export AR="$ndk_bin/llvm-ar" RANLIB="$ndk_bin/llvm-ranlib"
        export READELF="$ndk_bin/llvm-readelf"
        export CFLAGS="-O2 -fPIC -D__ANDROID_API__=$api -I$DEPS_PREFIX/include"
        export CPPFLAGS="-I$DEPS_PREFIX/include"
        export LDFLAGS="-L$DEPS_PREFIX/lib"
        export PKG_CONFIG_LIBDIR="$DEPS_PREFIX/lib/pkgconfig:$DEPS_PREFIX/share/pkgconfig"
        "$target_src/configure" \
            --host="$TRIPLET" \
            --build="$("$target_src/config.guess")" \
            --with-build-python="$host_prefix/bin/python$mm" \
            --prefix="$DEPS_PREFIX" \
            --enable-shared=no --without-ensurepip --disable-test-modules \
            --with-platlibdir=lib \
            ac_cv_file__dev_ptmx=no ac_cv_file__dev_ptc=no \
            ac_cv_buggy_getaddrinfo=no
        make -j"$JOBS"
        make install
    )

    [ -d "$DEPS_PREFIX/lib/python$mm" ] || {
        echo "CPython install did not create $DEPS_PREFIX/lib/python$mm" >&2
        return 1
    }
}
