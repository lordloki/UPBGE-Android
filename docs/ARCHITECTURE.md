# ARCHITECTURE.md

How the UPBGE Android build system fits together, from source checkout to a
running `.blend` on a phone.

## Bird's-eye view

```
HOST (Linux, NDK r29)
  scripts/fetch_upbge.sh       -> $UPBGE_SOURCE (UPBGE master + patches/upbge/*.patch)
  deps/build.sh                -> $BUILD_BASE/lib/android_<arch>   (static libraries)
  build.py player-only
    1. host tree    build_host_tools_<feature>/bin/{makesdna,makesrna,datatoc,shader_tool}
    2. target tree  build_android_<feature>_<arch>/bin/libupbgeplayer.so
         toolchain/android.toolchain.cmake   (NDK, PIC, hidden visibility, 16 KB pages)
         features/<feature>.cmake            (same initial cache as the host tree)
         cmake/upbge_android_project.cmake   (CMAKE_PROJECT_Blender_INCLUDE)
    3. scripts/package_player.sh -> android_apk_stage_<feature>_<arch>/*.apk
  scripts/verify_build.py      -> checks the stage

DEVICE (Android 12+, arm64, Vulkan 1.2)
  android.app.NativeActivity (no Java code) loads libupbgeplayer.so
    android_native_app_glue: ANativeActivity_onCreate, android_main() thread
    android_main()  GamePlayer/android/GPG_android_main.cpp
      - stdout/stderr -> logcat (tag UPBGE)
      - waits for the window, copies assets/upbge + game.blend to internal
        storage (only when assets/upbge/files.txt changed)
      - HOME, TMPDIR, BLENDER_SYSTEM_RESOURCES, BLENDER_USER_RESOURCES
      - GPG_main(upbgeplayer [blender_args.txt flags] -w <game.blend>)
    GPG_SystemAndroid / GPG_WindowAndroid (GHOST)
      - looper polled from processEvents(), touch = mouse, keys, Back = Esc
      - ANativeWindow -> GHOST_ContextVK (VK_KHR_android_surface)
      - lifecycle v1: APP_CMD_TERM_WINDOW stops presenting and quits the game;
        the process then finishes the activity and exits
```

## File map

| File / dir | Purpose |
| --- | --- |
| `build_files/android/env.sh` | Resolves NDK, SDK, JDK, host compiler, `BUILD_BASE`, `UPBGE_SOURCE`. Sourceable. |
| `build_files/android/build.py` | Orchestrator: prereqs → host tools → target configure → build → package → archive → optional install/run. |
| `build_files/android/deps/build.sh` | Cross-compiles every library into `lib/android_<arch>`. Sources each recipe from `deps/recipes/`. |
| `build_files/android/deps/recipes/*.sh` | One recipe per library. Contract documented in `deps/recipes/README.md`. |
| `build_files/android/toolchain/android.toolchain.cmake` | Thin wrapper over the NDK toolchain file (ABI/API defaults, try_compile forwarding, flags). |
| `build_files/android/cmake/upbge_android_project.cmake` | Injected after `project(Blender)`: host code generators, libutil stub, pkg-config isolation, Find hints, static link closure of the player. Blender's CMake is not edited. |
| `build_files/android/features/common.cmake` | Options shared by host and target: headless GHOST, Vulkan only, player only, audio, Python, strict build options. |
| `build_files/android/features/player_only.cmake` | Drops Cycles, OIDN, USD, simulation, importers and everything the deps prefix does not build. |
| `build_files/android/patches/upbge/0001-*.patch` | Blender-owned files (GHOST Vulkan context, `gpu/vulkan`), every hunk marked `UPBGE - Android`: Android surface and zero-cost pre-rotation. |
| `build_files/android/patches/upbge/0002-*.patch` | UPBGE-owned files: `GamePlayer/android/` backend and entry point, `GPG_ghost.cpp`, player CMake. |
| `build_files/android/patches/upbge/0003-*.patch` | Blender-owned files, marked like 0001: geometry shaders optional (Mali). Multi-viewport and barycentrics fall back when the matching extensions are missing. |
| `build_files/android/patches/upbge/0004-*.patch` | UPBGE `SpaceLogic` DNA: `[[deprecated]]` placed before the array field. Clang rejects it after the declarator. Drop once UPBGE master carries the fix. |
| `build_files/android/patches/oidn_android.diff`, `glog_android.diff` | Reference patches Wanderson carries for the `full` feature set. Not applied in current recipes. |
| `build_files/android/apk/` | `AndroidManifest.xml` (NativeActivity, `hasCode=false`) and `strings.xml`. |
| `build_files/android/debug.sh` | Read / write `blender_args.txt`, follow logcat, dump crash buffer. |
| `build_files/android/deploy.sh` | Install, run, capture log + screenshot. |
| `scripts/fetch_upbge.sh` | Clone UPBGE master, update submodules, apply patches. |
| `scripts/apply_patches.sh` | Idempotent `patch -p1` of `patches/upbge/*.patch`. `--reset` reverts. |
| `scripts/package_player.sh` | Stage resources + game + library, then aapt2 / zipalign / apksigner (debug key). |
| `scripts/verify_build.py` | Sanity-check: ELF type, exported `ANativeActivity_onCreate`, extraction manifest, AndroidManifest. |
| `Makefile` | Convenience wrapper: `setup-host`, `setup-sdk`, `setup`, `deps`, `build`, `package`, `deploy`, `verify`, `clean-build`, `clean-all`. |
| `Dockerfile` | Reproducible build image. Mount `BUILD_BASE` as a volume to keep the deps prefix. |
| `.github/workflows/build-android.yml` | CI: single target (arm64-v8a + player-only), deps cache, APK artifact, GitHub Release on tag. |

## Host code generators

`makesdna`, `makesrna`, `datatoc` and `shader_tool` run during the build, so
they must be host binaries. `build.py` configures the same UPBGE tree for the
host with the same feature cache and builds only those four targets; this
needs the libraries a normal desktop UPBGE build uses (Blender's precompiled
`lib/linux_x64` from `make update`, or distribution packages including
Python 3.13). In the target tree the project include lets each tool target
build as usual, then overwrites its output with the host binary
(`POST_BUILD`); every custom command calls the tool through
`$<TARGET_FILE:...>`, so it runs the host one.

The feature files set `WITH_STRICT_BUILD_OPTIONS`: a library missing on
either side fails that configure instead of switching a feature off on one
side only, which would make `makesrna` disagree with the target.

## Static link closure

Without `LIBDIR`, Blender's Find modules return one archive per library, while
every dependency is a static archive with its own dependencies (libsndfile →
FLAC/Ogg/Vorbis/Opus, libpython → libintl, ...). The project include asks
`pkg-config --static` for the closure of the libraries the player uses and adds
each archive that exists in the deps prefix to `blenderplayer`. lld resolves
archives in any order and pulls only the members it needs.

## Display rotation

The swapchain is created in the display's identity orientation with
`preTransform = currentTransform`, and the existing back buffer → swapchain
copy becomes a compute pass that writes the frame rotated
(`vk_backbuffer_rotate`). SurfaceFlinger then has no rotation pass to do.
When the surface cannot be pre-rotated (no STORAGE usage, format other than
RGBA8, HDR) the swapchain stays IDENTITY and the compositor rotates.

## GPUs without geometry shaders

No UPBGE shader has a geometry stage; the Vulkan backend only injects one to
emulate `VK_EXT_shader_viewport_index_layer` (EEVEE shadows) or
`VK_KHR_fragment_shader_barycentric` (Wireframe node, Geometry > Parametric).
On a device without geometry shaders (Mali), patch 0003 turns off
multi-viewport (EEVEE renders every shadow tile into the largest viewport) and
compiles barycentric materials without barycentrics, unless the extensions
are present.

## Build directory layout

```
$BUILD_BASE/
├── lib/
│   └── android_arm64-v8a/         # deps prefix (only target ABI)
│       ├── include/...
│       └── lib/*.a  (+ libvulkan.so, the NDK link stub)
├── deps_src/arm64-v8a/            # extracted tarballs
├── deps_build/arm64-v8a/          # out-of-tree builds of deps
├── build_host_tools_player-only/
│   └── bin/{makesdna,makesrna,datatoc,shader_tool}
├── build_android_player-only_arm64-v8a/
│   └── bin/libupbgeplayer.so
├── android_apk_stage_player-only_arm64-v8a/
│   ├── lib/arm64-v8a/libupbgeplayer.so
│   ├── assets/{game.blend,upbge/}
│   └── upbge-player-player-only-arm64-v8a.apk
├── logs/
│   └── deps_arm64-v8a.log
└── apk/
    ├── upbge-player-player-only-arm64-v8a-<date>.apk
    └── upbge-player-player-only-arm64-v8a-latest.apk -> ...apk
```
