#!/usr/bin/env bash
# Shared dependency build helpers. Sourced by deps/build.sh.

_download_name() {
    local url="$1"
    url="${url%%\?*}"
    printf '%s' "${url##*/}"
}

# download_and_extract URL DIR
# Idempotent: a tree is reused only if a previous extraction completed (stamp
# file); anything else is a partial tree and is extracted again from scratch.
download_and_extract() {
    local url="$1" dest="$2" cache archive name
    cache="$SRC_DIR/.downloads"
    name="$(_download_name "$url")"
    # GitHub tag archives are all called v<tag>.tar.gz (shaderc and
    # SPIRV-Tools are both v2024.1.tar.gz): key the cache by destination too.
    archive="$cache/$(basename "$dest")--$name"
    mkdir -p "$cache"
    if [ ! -s "$archive" ]; then
        echo "  downloading $url"
        rm -f "$archive.tmp"
        curl --fail --location --retry 4 --retry-delay 2 --connect-timeout 30 \
            --output "$archive.tmp" "$url"
        mv "$archive.tmp" "$archive"
    fi
    if [ -f "$dest/.upbge_extracted" ]; then
        return 0
    fi
    rm -rf "$dest"
    mkdir -p "$dest"
    case "$name" in
        *.tar.gz|*.tgz) tar -xzf "$archive" -C "$dest" --strip-components=1 ;;
        *.tar.bz2|*.tbz2) tar -xjf "$archive" -C "$dest" --strip-components=1 ;;
        *.tar.xz|*.txz) tar -xJf "$archive" -C "$dest" --strip-components=1 ;;
        *.tar) tar -xf "$archive" -C "$dest" --strip-components=1 ;;
        *.zip) unzip -q "$archive" -d "$dest" ;;
        *) echo "Unsupported source archive: $name" >&2; return 1 ;;
    esac
    : > "$dest/.upbge_extracted"
}

# cmake_android SRC BUILD [CMake options...]
# The build directory is always recreated: completed recipes are skipped by
# deps/build.sh, so a rerun only happens after a failure, and a stale
# CMakeCache from that failure (or from an older toolchain) must not leak in.
cmake_android() {
    local src="$1" bld="$2"; shift 2
    [ -f "$src/CMakeLists.txt" ] || { echo "Missing CMakeLists.txt: $src" >&2; return 1; }
    rm -rf "$bld"
    mkdir -p "$bld"
    # CMAKE_INSTALL_LIBDIR is typed: an untyped relative value is turned into
    # $PWD/lib by projects that bundle their own GNUInstallDirs (libjpeg-turbo).
    # CMAKE_POLICY_VERSION_MINIMUM: CMake >= 4.0 (openSUSE Tumbleweed, Arch)
    # rejects cmake_minimum_required(VERSION < 3.5), used by lz4, libjpeg-turbo,
    # freetype and openal-soft. It is ignored by older CMake.
    cmake -S "$src" -B "$bld" -G Ninja \
        -DCMAKE_TOOLCHAIN_FILE="$DEPS_TOOLCHAIN" \
        -DANDROID_ABI="$ARCH" \
        -DANDROID_PLATFORM="$ANDROID_PLATFORM" \
        -DANDROID_NDK="$ANDROID_NDK_HOME" \
        -DCMAKE_FIND_ROOT_PATH="$DEPS_PREFIX" \
        -DCMAKE_PREFIX_PATH="$DEPS_PREFIX" \
        -DCMAKE_INSTALL_PREFIX="$DEPS_PREFIX" \
        -DCMAKE_INSTALL_LIBDIR:PATH=lib \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DBUILD_TESTING=OFF \
        "$@"
    cmake --build "$bld" --parallel "$JOBS"
    cmake --install "$bld"
}

# autotools_android SRC BUILD [configure options...]
# Out-of-tree build in a fresh BUILD directory; the source tree stays pristine
# so the same sources can be configured twice (fftw3 float + double).
autotools_android() {
    local src="$1" bld="$2"; shift 2
    local api="${ANDROID_PLATFORM#android-}"
    local ndk_bin="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$NDK_HOST_OS_TAG/bin"
    local cc="$ndk_bin/${TRIPLET}${api}-clang"
    local cxx="$ndk_bin/${TRIPLET}${api}-clang++"
    [ -x "$cc" ] || { echo "NDK compiler not found: $cc" >&2; return 1; }
    [ -x "$src/configure" ] || { echo "Missing configure script: $src" >&2; return 1; }
    rm -rf "$bld"
    mkdir -p "$bld"
    (
        cd "$bld"
        export CC="$cc" CXX="$cxx"
        export AR="$ndk_bin/llvm-ar" RANLIB="$ndk_bin/llvm-ranlib"
        export STRIP="$ndk_bin/llvm-strip" NM="$ndk_bin/llvm-nm"
        export CFLAGS="-O2 -fPIC ${EXTRA_CFLAGS:-}"
        export CXXFLAGS="$CFLAGS"
        export CPPFLAGS="-I$DEPS_PREFIX/include ${EXTRA_CPPFLAGS:-}"
        export LDFLAGS="-L$DEPS_PREFIX/lib ${EXTRA_LDFLAGS:-}"
        # --libdir is explicit: openSUSE's CONFIG_SITE would otherwise turn
        # the default ${exec_prefix}/lib into lib64 (also neutralized in build.sh).
        "$src/configure" --host="$TRIPLET" --prefix="$DEPS_PREFIX" \
            --libdir="$DEPS_PREFIX/lib" \
            --disable-shared --enable-static "$@"
        make -j"$JOBS"
        make install
    )
}

cmake_android_host_tools() {
    echo "Host tool builds must be implemented explicitly by the recipe" >&2
    return 2
}
