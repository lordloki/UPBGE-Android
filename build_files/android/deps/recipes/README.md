# Android dependency recipes

Each recipe defines `recipe_<name>()` and is sourced by `deps/build.sh`. The
active list in `deps/build.sh` is the authoritative player-only dependency set.

## Build helpers

- `download_and_extract URL DIR` caches source archives under `$SRC_DIR/.downloads`.
- `cmake_android SRC BUILD [CMake options...]` cross-compiles and installs with
  the repository Android toolchain.
- `autotools_android SRC BUILD [configure options...]` uses the NDK Clang
  wrappers, `llvm-ar`, and `llvm-ranlib` for static cross-builds.

Recipes that are not listed in `deps/build.sh` are not part of the current
player-only build. Some historical full-Blender recipe files remain in this
directory as inactive placeholders and are not loaded.

## Important Android-specific decisions

- Boost uses Boost.Build (`b2`), not CMake.
- OpenEXR builds its matching Imath dependency first.
- FFmpeg is built as static libraries with the required internal decoders; it
  does not probe host codec libraries.
- shaderc synchronizes the dependency revisions pinned by its release.
- GLEW is explicitly skipped: desktop GLEW is not an Android GLES loader.
- Vulkan's runtime loader is supplied by Android; the app must link the NDK
  Vulkan stub and must not package a competing Vulkan loader.

The recipes have been syntax-checked and statically reviewed. They have not been
compiled on an Android NDK in this environment; a successful dependency build
and final UPBGE link are still required before treating the set as validated.
