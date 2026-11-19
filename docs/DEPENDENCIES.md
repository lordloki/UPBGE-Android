# DEPENDENCIES.md

The dependency prefix `$BUILD_BASE/lib/android_<arch>/` is built by
`build_files/android/deps/build.sh`, which sources one recipe per library
from `deps/recipes/*.sh`. This page documents the list and the rationale for
each entry.

## Recipes (29 libraries)

These are the libraries the `blenderplayer` runtime needs to boot a
`.blend` and run a game. The list is fixed (no feature-set variants):

### Core compression / data
| Lib | Why |
| --- | --- |
| zlib | PNG, OpenEXR, Python, ... |
| zstd | Compression used by various deps (FFmpeg, OpenEXR, ...). |
| lz4 | OpenEXR's compression |
| gettext | i18n stubs (linked but unused at runtime) |
| sqlite | Some Python modules and UPBGE's asset library |

### Images
| Lib | Why |
| --- | --- |
| libpng | PNG textures |
| libjpeg | JPEG textures (libjpeg-turbo) |
| libwebp | WebP textures |
| openjpeg | JPEG 2000 (used by some .blend files) |
| tiff | TIFF textures (DDS, HDR are in-tree) |
| openexr | EXR textures; required by some Python image modules. |

### Fonts / text
| Lib | Why |
| --- | --- |
| freetype | Font rendering |

### Audio
| Lib | Why |
| --- | --- |
| fftw3 | UPBGE audio FFT analyzers |
| sndfile | Reading .wav / .flac / .ogg in the game |
| flac, vorbis, ogg, opus | Audio codecs used by FFmpeg |
| openal | 3D positional audio (OpenSL ES backend on Android) |
| ffmpeg | Game video / audio container decoding |
| sdl2 | Optional alternative audio backend (off in player-only) |

### Graphics
| Lib | Why |
| --- | --- |
| glew | Explicitly skipped; desktop GLEW is not an Android GLES loader. |
| shaderc, spirv-tools | GLSL → SPIR-V compilation for EEVEE Next |
| vulkan_headers | `vulkan/vulkan.h` |
| vulkan_loader | Loader / stub so `find_package(Vulkan)` succeeds |

### Python
| Lib | Why |
| --- | --- |
| python | CPython 3.11, cross-compiled. The stdlib ships inside `blender_runtime.zip`. |

### Misc
| Lib | Why |
| --- | --- |
| android_extra | The NDK-bundled `android_native_app_glue.c` copied into the prefix. |


## Build notes

- CMake recipes use the shared Android toolchain and install into the common prefix.
- Autotools recipes use the NDK Clang wrapper for the selected API level and static libraries.
- Boost is built with Boost.Build, not CMake.
- OpenEXR first builds the matching Imath release.
- shaderc requires its pinned glslang/SPIRV-Headers/SPIRV-Tools sources; its sync script fetches those dependencies.
- GLEW is headers-only because desktop GLEW is not an Android GLES loader.

JPEG XT is intentionally excluded from the active list: it is optional and
not required by the player runtime.

## Versions

Versions are pinned in each recipe file. The CI workflow rebuilds the
dependency cache when any file under `build_files/android/deps/` changes
(which is detected by `hashFiles('build_files/android/deps/**/*.sh')`).

## Patches shipped (reference, not applied in current recipes)

The `build_files/android/patches/` directory carries patches that Wanderson
applied to dependencies that the `full` feature set used. The current
`player-only` recipe list does not build those libraries, so the patches are
kept as reference for anyone who re-enables `full` later:

| Patch | Applies to | Reason |
| --- | --- | --- |
| `oidn_android.diff` | OpenImageDenoise | Bionic exposes `pthread_*affinity_*` only from API 36; redirect to `sched_*`. |
| `glog_android.diff` | glog | Bionic lacks `<execinfo.h>` below API 33; disable the stacktrace path. |

## Disk budget

| Item | Size |
| --- | --- |
| `deps_src/<arch>/` | ~5 GB per arch |
| `deps_build/<arch>/` | ~10 GB per arch |
| `lib/android_<arch>/` | ~2 GB per arch (mostly Python) |
| `build_host_tools_player-only/` | ~1 GB |
| `build_android_player-only_<arch>/` | ~15 GB |
| `android_apk_stage_player-only_<arch>/` | ~250 MB |
| **Total per arch** | **~35 GB** |

For the single-target CI (arm64-v8a + player-only), budget ~40 GB.
The GitHub Action caches the dependency prefix, so only the first
run on a new commit pays the initial cost.
