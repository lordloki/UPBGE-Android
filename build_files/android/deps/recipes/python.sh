#!/usr/bin/env bash
# CPython 3.13 cross-build (UPBGE master requires 3.13; Android is an official
# tier-3 target since 3.13). The host interpreter supplies build-time Python
# tools; target objects are always compiled with the Android NDK.
#
# One pristine source tree, two out-of-tree builds (host, target).
#
# Every stdlib extension module is linked INTO libpython3.13.a
# (MODULE_BUILDTYPE=static): Android's linker never resolves a dlopen()ed
# module's undefined Py* symbols against an already loaded library (not even
# RTLD_GLOBAL, android/ndk#1244), so lib-dynload/*.so modules could not find
# the interpreter statically linked into the player .so. Built-in modules also
# skip one dlopen + relocation pass per import.
recipe_python() {
    local ver=3.13.13 mm=3.13
    local src="$SRC_DIR/Python-$ver"
    local host_build="$BUILD_DIR_BASE/python-host-build" host_prefix="$BUILD_DIR_BASE/python-host"
    local target_build="$BUILD_DIR_BASE/python-$ARCH"
    local api="${ANDROID_PLATFORM#android-}"
    local ndk_bin="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$NDK_HOST_OS_TAG/bin"

    download_and_extract "https://www.python.org/ftp/python/$ver/Python-$ver.tar.xz" "$src"

    if [ ! -x "$host_prefix/bin/python$mm" ]; then
        rm -rf "$host_build"
        mkdir -p "$host_build" "$host_prefix"
        # Use the selected host compiler: the system default `cc` may be newer
        # than this CPython release was tested with.
        ( cd "$host_build"
          # build.sh points PKG_CONFIG_LIBDIR at the Android prefix; configure
          # would then hand -L<arm64 prefix> -lz to the host linker. The host
          # interpreter must only see host libraries: restore the default path.
          unset PKG_CONFIG_LIBDIR
          CC="${HOST_CC:-cc}" "$src/configure" --prefix="$host_prefix" \
              --without-ensurepip --disable-test-modules
          make -j"$JOBS"
          make install
        )
    fi

    rm -rf "$target_build"
    mkdir -p "$target_build"
    (
        cd "$target_build"
        export PATH="$ndk_bin:$PATH"
        export CC="$ndk_bin/${TRIPLET}${api}-clang"
        export CXX="$ndk_bin/${TRIPLET}${api}-clang++"
        export AR="$ndk_bin/llvm-ar" RANLIB="$ndk_bin/llvm-ranlib"
        export NM="$ndk_bin/llvm-nm" STRIP="$ndk_bin/llvm-strip"
        export READELF="$ndk_bin/llvm-readelf"
        # Same as CPython's Android/android-env.sh: no compile-time PAGE_SIZE,
        # so the result also runs on 16 KB page devices.
        export CFLAGS="-O2 -fPIC -D__BIONIC_NO_PAGE_SIZE_MACRO"
        export CPPFLAGS="-I$DEPS_PREFIX/include"
        export LDFLAGS="-L$DEPS_PREFIX/lib -lm"
        # CPython's locale module uses GNU gettext when libintl.h is available.
        # Link the Android gettext runtime explicitly to resolve libintl_* symbols.
        # (lib64 cannot happen any more: build.sh neutralizes openSUSE's
        # CONFIG_SITE and the helpers pass --libdir explicitly.)
        if [ ! -f "$DEPS_PREFIX/lib/libintl.a" ]; then
            echo "gettext static library not found: $DEPS_PREFIX/lib/libintl.a" >&2
            echo "Build the gettext recipe before Python and verify its installation." >&2
            exit 1
        fi
        export LIBS="-lintl ${LIBS:-}"
        # The bundled expat only renames the public XML_* API (pyexpatns.h);
        # its internal globals would clash with the prefix libexpat that
        # OpenColorIO links. Use that one: a single expat in the player.
        "$src/configure" \
            --host="$TRIPLET" \
            --build="$("$src/config.guess")" \
            --with-build-python="$host_prefix/bin/python$mm" \
            --prefix="$DEPS_PREFIX" --libdir="$DEPS_PREFIX/lib" \
            --disable-shared --without-ensurepip --disable-test-modules \
            --with-system-expat \
            --with-platlibdir=lib \
            MODULE_BUILDTYPE=static
        make -j"$JOBS"
        make install
        # Built-in modules put their objects in libpython, but the helper
        # archives they need (libmpdec, HACL*) stay in the build
        # tree: CPython only adds them (MODLIBS) when linking its own
        # executable, and python-embed.pc does not list them. Merge them so
        # libpython is self-contained for the player link.
        local lib="$DEPS_PREFIX/lib/libpython$mm.a" a
        {
            echo "create $lib.merged"
            echo "addlib $lib"
            for a in $(find Modules -name 'lib*.a' | sort); do
                echo "addlib $a"
            done
            echo "save"
            echo "end"
        } | "$ndk_bin/llvm-ar" -M
        mv -f "$lib.merged" "$lib"
    )

    [ -f "$DEPS_PREFIX/lib/libpython$mm.a" ] || {
        echo "CPython install did not create $DEPS_PREFIX/lib/libpython$mm.a" >&2
        return 1
    }
}
