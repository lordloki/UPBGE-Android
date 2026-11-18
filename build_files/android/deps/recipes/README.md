# build_files/android/deps/recipes/

Each file `<name>.sh` defines a Bash function `recipe_<name>` that downloads,
patches (if needed), cross-compiles, and installs one library into
`$DEPS_PREFIX` (i.e. `$BUILD_BASE/lib/android_<arch>`).

## Environment variables already set when the recipe is sourced

| Variable             | Meaning                                                         |
| -------------------- | --------------------------------------------------------------- |
| `$ARCH`              | `arm64-v8a` or `armeabi-v7a`                                    |
| `$TRIPLET`           | NDK CMake triplet, e.g. `aarch64-linux-android`                 |
| `$FEATURE`           | `player-only` or `full`                                         |
| `$JOBS`              | parallelism (typically `nproc`)                                 |
| `$DEPS_PREFIX`       | install prefix (lib/ include/)                                  |
| `$SRC_DIR`           | where sources are extracted                                     |
| `$BUILD_DIR_BASE`    | where out-of-tree builds go                                     |
| `$DEPS_TOOLCHAIN`    | path to `android.toolchain.cmake`                               |
| `$HOST_CC`           | host CC (for `CC=$HOST_CC` if a host-side tool is needed)       |
| `$HOST_CXX`          | host CXX                                                        |
| `$NDK_HOST_OS_TAG`   | e.g. `linux-x86_64`                                             |

## Recipe skeleton

```bash
recipe_zlib() {
    local ver="1.3.1"
    local src="$SRC_DIR/zlib-$ver"
    local url="https://zlib.net/fossils/zlib-$ver.tar.gz"

    if [ ! -d "$src" ]; then
        download_and_extract "$url" "$src"
    fi

    local bld="$BUILD_DIR_BASE/zlib-$ARCH"
    mkdir -p "$bld"
    cmake -G Ninja -S "$src" -B "$bld" \
        -DCMAKE_TOOLCHAIN_FILE="$DEPS_TOOLCHAIN" \
        -DANDROID_ABI="$ARCH" \
        -DANDROID_PLATFORM="android-31" \
        -DANDROID_NDK="$ANDROID_NDK_HOME" \
        -DCMAKE_INSTALL_PREFIX="$DEPS_PREFIX" \
        -DCMAKE_BUILD_TYPE=Release
    cmake --build "$bld" --target install -- -j"$JOBS"
}
```

## Helper functions (defined in deps/build.sh)

- `download_and_extract URL DIR` — `wget -O` + `tar xf` into `DIR`. Detects
  `.tar.gz`, `.tar.bz2`, `.tar.xz`, `.zip` from the extension.

## Patching a library

If a library needs an Android patch (like OIDN or glog), reference the diff
from `build_files/android/patches/` inside the recipe:

```bash
recipe_openimagedenoise() {
    ...
    cd "$src"
    patch -p1 < "$UPBGE_ANDROID_ROOT/build_files/android/patches/oidn_android.diff"
    ...
}
```

## Status

The 30 recipes that ship in this directory cover the entire dependency list
the system needs (zlib, zstd, libpng, libjpeg, freetype, Python, ffmpeg,
OpenAL, Vulkan loader, ...). There is no `full` feature set; the player-only
list is the only one.

The full reference for every recipe is Wanderson's
`build_files/android/deps/build.sh` at:

    https://github.com/Wanderson-Magalhaes/blender_for_android/blob/main/build_files/android/deps/build.sh
