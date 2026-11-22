# Android dependency recipes

Each recipe defines `recipe_<name>()` and is sourced by `deps/build.sh`. The
active list in `deps/build.sh` is the authoritative player-only dependency set.

## Build helpers

- `download_and_extract URL DIR` caches source archives under `$SRC_DIR/.downloads`
  (keyed by destination, so identical tag names cannot collide) and re-extracts
  any tree that lacks the `.upbge_extracted` completion stamp.
- `cmake_android SRC BUILD [CMake options...]` cross-compiles and installs with
  the repository Android toolchain (a wrapper over the NDK's own toolchain file)
  into `$DEPS_PREFIX/lib`, from a fresh build directory.
- `autotools_android SRC BUILD [configure options...]` configures out of tree
  in a fresh BUILD directory with the NDK Clang wrappers, `llvm-ar`, and
  `llvm-ranlib` for static cross-builds, with an explicit `--libdir`.

Recipes run in a subshell with `set -euo pipefail` active: the first failing
command aborts the recipe. Do not reference a variable in the same `local`
statement that assigns it (`local ver=1 src=x-$ver`): bash expands every word
before assigning, so `$ver` is unset there. Keep shared objects out of the prefix (delete them
after install if a project always builds one) so the player links statically.

Recipes that are not listed in `deps/build.sh` are not part of the current
player-only build. Some historical full-Blender recipe files remain in this
directory as inactive placeholders and are not loaded.

## Important Android-specific decisions

- OpenEXR builds its matching Imath dependency first; OpenJPH is a separate
  recipe because a static OpenEXR cannot export its vendored copy.
- libtiff's static `TiffConfig.cmake` does not import its dependencies; the
  recipe patches the installed file so OIIO/Blender can configure.
- CPython 3.13 is static with `MODULE_BUILDTYPE=static`: Android cannot
  resolve a dlopen()ed extension module against a statically linked interpreter.
- FFmpeg is built as static libraries with the required internal decoders; it
  does not probe host codec libraries. All seven libraries Blender's
  FindFFmpeg requires are built (avdevice/avfilter without devices/filters).
- FFTW is built twice (float and double): Blender's FindFftw3 needs both.
- OpenAL is built with `LIBTYPE=STATIC`; the final link must add `OpenSLES`.
- shaderc synchronizes the dependency revisions pinned by its release.
- GLEW is explicitly skipped: desktop GLEW is not an Android GLES loader.
- Vulkan's runtime loader is supplied by Android; the app must link the NDK
  Vulkan stub and must not package a competing Vulkan loader.

The recipes have been syntax-checked and statically reviewed. They have not been
compiled on an Android NDK in this environment; a successful dependency build
and final UPBGE link are still required before treating the set as validated.
