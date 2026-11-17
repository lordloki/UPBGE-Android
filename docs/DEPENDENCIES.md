# DEPENDENCIES.md

The dependency prefix `$BUILD_BASE/lib/android_<arch>/` is built by
`build_files/android/deps/build.sh`, which sources one recipe per library
from `deps/recipes/*.sh`. This page documents the list and the rationale for
each entry.

## player-only (50 recipes)

These are the minimum libraries the `blenderplayer` runtime needs to boot a
`.blend` and run a game:

### Core compression / data
| Lib | Why |
| --- | --- |
| zlib | PNG, OpenEXR, Python, ... |
| zstd | USD's compression (only if USD is on; kept for `full`) |
| lz4 | OpenEXR's compression |
| gettext | i18n stubs (linked but unused at runtime) |
| sqlite | Some Python modules and UPBGE's asset library |
| iconv, intl, xml2, pcre2 | Python dependencies (charset, locale, regex) |

### Images
| Lib | Why |
| --- | --- |
| libpng | PNG textures |
| libjpeg | JPEG textures (libjpeg-turbo) |
| libwebp | WebP textures |
| openjpeg | JPEG 2000 (used by some .blend files) |
| tiff | TIFF textures (DDS, HDR are in-tree) |
| openexr | EXR textures (only if `WITH_IMAGE_OPENEXR=ON`; off in player-only) |

### Fonts / text
| Lib | Why |
| --- | --- |
| freetype | Font rendering |
| freetype_extras | HarfBuzz, Brotli (optional, off in player-only) |

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
| glew | (Stubbed; only used by legacy GL paths; off on Android) |
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
| jpeg-xt | 12-bit JPEG support, optional. |

## full (23 additional recipes, ~73 total)

Everything above plus the heavy libraries that the **Blender editor** and
**Cycles** depend on. These are stubs in `deps/recipes/` and must be filled
in before `make deps FEATURE=full` works fully — each file points at Wanderson's
`deps/build.sh` for the canonical recipe.

### Threading
- tbb (oneTBB)

### Geometry / mesh processing
- gmp, mpfr (arbitrary precision)
- opensubdiv (subdivision surface evaluation)
- manifold (Manifold mesh library)
- draco (mesh compression)
- openpgl (path guiding, for Cycles)
- potrace (trace bitmaps to curves)

### Render
- embree (ray tracing, for Cycles)
- openimagedenoise (OIDN; carries the Android patch)
- openshadinglanguage (OSL, for Cycles shading)
- ceres-solver (used by motion tracking)
- openvdb (sparse volumetric data; depends on tbb + boost)

### I/O
- openimageio (image I/O framework; depends on boost, openexr, ffmpeg, ...)
- hdf5 (Alembic's container)
- alembic (.abc cache format)
- usd (Pixar USD; huge)
- materialx (Material exchange format)
- pugixml (XML parser, for various file formats)

### Math / utility
- boost (boost::filesystem, system, thread, regex, ...)
- pystring (Python-style string ops in C++)

## Versions

Versions are pinned in each recipe file. The CI workflow rebuilds the
dependency cache when any file under `build_files/android/deps/` changes
(which is detected by `hashFiles('build_files/android/deps/**/*.sh')`).

## Patches applied during the deps build

| Lib | Patch | Reason |
| --- | --- | --- |
| openimagedenoise | `patches/oidn_android.diff` | Bionic exposes `pthread_*affinity_*` only from API 36; redirect to `sched_*`. |
| glog | `patches/glog_android.diff` | Bionic lacks `<execinfo.h>` below API 33; disable the stacktrace path. |

Apply patterns:

```bash
# inside the recipe:
patch -d "$src" -p1 < "$UPBGE_ANDROID_ROOT/build_files/android/patches/oidn_android.diff"
```

## Disk budget

| Item | Size |
| --- | --- |
| `deps_src/<arch>/` | ~5 GB per arch |
| `deps_build/<arch>/` | ~10 GB per arch |
| `lib/android_<arch>/` | ~2 GB per arch (mostly Python) |
| `build_host_tools_<feature>/` | ~1 GB |
| `build_android_<feature>_<arch>/` | ~15 GB |
| `android_apk_stage_<...>/` | ~250 MB (player-only) or ~600 MB (full) |
| **Total per (arch × feature)** | **~35 GB** |

For the 1×2 CI matrix (arm64-v8a × player-only + full), budget ~70 GB.
The GitHub Action caches the dependency prefix per cell, so only the first
run on a new commit pays the full cost.
