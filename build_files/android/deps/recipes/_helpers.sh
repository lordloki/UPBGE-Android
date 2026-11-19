#!/usr/bin/env bash
# Shared dependency build helpers. Sourced by deps/build.sh.

_download_name() {
    local url="$1"
    url="${url%%\?*}"
    printf '%s' "${url##*/}"
}

download_and_extract() {
    local url="$1" dest="$2" cache archive name
    cache="$SRC_DIR/.downloads"
    name="$(_download_name "$url")"
    archive="$cache/$name"
    mkdir -p "$cache" "$dest"
    if [ ! -s "$archive" ]; then
        echo "  downloading $url"
        curl --fail --location --retry 4 --retry-delay 2 --connect-timeout 30 \
            --output "$archive.tmp" "$url"
        mv "$archive.tmp" "$archive"
    fi
    # Do not silently reuse a partially extracted source tree.
    if [ -n "$(find "$dest" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
        return 0
    fi
    case "$name" in
        *.tar.gz|*.tgz) tar -xzf "$archive" -C "$dest" --strip-components=1 ;;
        *.tar.bz2|*.tbz2) tar -xjf "$archive" -C "$dest" --strip-components=1 ;;
        *.tar.xz|*.txz) tar -xJf "$archive" -C "$dest" --strip-components=1 ;;
        *.tar) tar -xf "$archive" -C "$dest" --strip-components=1 ;;
        *.zip) unzip -q "$archive" -d "$dest" ;;
        *) echo "Unsupported source archive: $name" >&2; return 1 ;;
    esac
}

cmake_android() {
    local src="$1" bld="$2"; shift 2
    [ -f "$src/CMakeLists.txt" ] || { echo "Missing CMakeLists.txt: $src" >&2; return 1; }
    mkdir -p "$bld"
    cmake -S "$src" -B "$bld" -G Ninja \
        -DCMAKE_TOOLCHAIN_FILE="$DEPS_TOOLCHAIN" \
        -DANDROID_ABI="$ARCH" \
        -DANDROID_PLATFORM="$ANDROID_PLATFORM" \
        -DANDROID_NDK="$ANDROID_NDK_HOME" \
        -DCMAKE_FIND_ROOT_PATH="$DEPS_PREFIX" \
        -DCMAKE_PREFIX_PATH="$DEPS_PREFIX" \
        -DCMAKE_INSTALL_PREFIX="$DEPS_PREFIX" \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_POSITION_INDEPENDENT_CODE=ON \
        -DBUILD_TESTING=OFF \
        "$@"
    cmake --build "$bld" --parallel "$JOBS"
    cmake --install "$bld"
}

autotools_android() {
    local src="$1" bld="$2"; shift 2
    local api="${ANDROID_PLATFORM#android-}"
    local ndk_bin="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$NDK_HOST_OS_TAG/bin"
    local cc="$ndk_bin/${TRIPLET}${api}-clang"
    local cxx="$ndk_bin/${TRIPLET}${api}-clang++"
    [ -x "$cc" ] || { echo "NDK compiler not found: $cc" >&2; return 1; }
    mkdir -p "$bld"
    (
        cd "$src"
        export CC="$cc" CXX="$cxx"
        export AR="$ndk_bin/llvm-ar" RANLIB="$ndk_bin/llvm-ranlib"
        export STRIP="$ndk_bin/llvm-strip" NM="$ndk_bin/llvm-nm"
        export CFLAGS="-O2 -fPIC -D__ANDROID_API__=$api ${EXTRA_CFLAGS:-}"
        export CXXFLAGS="$CFLAGS"
        export CPPFLAGS="-I$DEPS_PREFIX/include ${EXTRA_CPPFLAGS:-}"
        export LDFLAGS="-L$DEPS_PREFIX/lib ${EXTRA_LDFLAGS:-}"
        export PKG_CONFIG_LIBDIR="$DEPS_PREFIX/lib/pkgconfig:$DEPS_PREFIX/share/pkgconfig"
        export PKG_CONFIG_SYSROOT_DIR="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$NDK_HOST_OS_TAG/sysroot"
        ./configure --host="$TRIPLET" --prefix="$DEPS_PREFIX" \
            --disable-shared --enable-static "$@"
        make -j"$JOBS"
        make install
    )
}

cmake_android_host_tools() {
    echo "Host tool builds must be implemented explicitly by the recipe" >&2
    return 2
}
