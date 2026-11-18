# ARCHITECTURE.md

How the UPBGE Android build system fits together, from source checkout to a
running `.blend` on a phone.

## Bird's-eye view

```
┌────────────────────────────────────────────────────────────────────────────┐
│ HOST (Ubuntu 22.04, GCC 14, NDK r26d)                                       │
│                                                                              │
│   scripts/fetch_upbge.sh ──▶ ~/upbge_src  (UPBGE master + Android patches) │
│                                                                              │
│   build_files/android/deps/build.sh ──▶ cross-compile 50-73 libraries       │
│                                          into lib/android_<arch>/           │
│                                                                              │
│   build_files/android/build.py <feature> --arch <arch>:                     │
│      ├── host code generators (makesdna, makesrna, ...)                     │
│      ├── target build (CMake + Ninja + toolchain/android.toolchain.cmake)   │
│      └── scripts/package_player.sh                                          │
│            ├── lib/<arch>/libupbgeplayer.so                                 │
│            ├── assets/blender_runtime.zip                                   │
│            ├── assets/game.blend   (placeholder)                            │
│            ├── AndroidManifest.xml + MainActivity.java                      │
│            └── build/upbge-player-unsigned.apk  (if aapt2 present)          │
│                                                                              │
│   scripts/verify_build.py ──▶ sanity-check the bundle                       │
└────────────────────────────────────────────────────────────────────────────┘
                                       │
                                       ▼
┌────────────────────────────────────────────────────────────────────────────┐
│ DEVICE (Android 12+, arm64, Vulkan)                                          │
│                                                                              │
│   org.upbge.player.MainActivity                                              │
│      ├── System.loadLibrary("upbgeplayer")                                  │
│      ├── SurfaceHolder.Callback → ANativeWindow                             │
│      └── JNI: nativeOnSurfaceCreated / nativeOnPause / ...                  │
│                                                                              │
│   libupbgeplayer.so                                                          │
│      ├── android_main()   (entry point from native_app_glue)                │
│      │     ├── spawns player_main() thread                                  │
│      │     └── runs GHOST event loop until destroyRequested                 │
│      ├── GHOST_SystemAndroid → GHOST_WindowAndroid                          │
│      │     └── ANativeWindow → VkSurfaceKHR                                 │
│      └── player_main() calls BLI_main("blenderplayer", "-w", ...)           │
│            └── UPBGE game engine boots, loads assets/game.blend             │
└────────────────────────────────────────────────────────────────────────────┘
```

## File map

| File / dir | Purpose |
| --- | --- |
| `build_files/android/env.sh` | Resolves NDK, SDK, JDK, host compiler, `BUILD_BASE`, `UPBGE_SOURCE`. Sourceable. |
| `build_files/android/build.py` | The orchestrator. Stages: prereqs check → host tools → target configure → build → repackage → archive → optional install/run. |
| `build_files/android/deps/build.sh` | Cross-compiles every library into `lib/android_<arch>`. Sources each recipe from `deps/recipes/`. |
| `build_files/android/deps/recipes/*.sh` | One recipe per library. Contract documented in `deps/recipes/README.md`. |
| `build_files/android/toolchain/android.toolchain.cmake` | CMake toolchain for the NDK. Sets compilers, sysroot, `CMAKE_FIND_ROOT_PATH`, link flags. |
| `build_files/android/features/common.cmake` | Shared Android toggles: `WITH_ANDROID`, `WITH_GHOST_ANDROID`, Vulkan, audio, Python, etc. |
| `build_files/android/features/player_only.cmake` | `WITH_BLENDER=OFF`, `WITH_PLAYER=ON`, drops Cycles/OIDN/USD/... |
| `build_files/android/patches/0001-GHOST-Android-minimal-backend.patch` | Wires `WITH_GHOST_ANDROID` into `intern/ghost/CMakeLists.txt` and `source/gameengine/CMakeLists.txt`. |
| `build_files/android/patches/ghost_android/` | The actual GHOST Android backend files (`.cc` / `.hh`), copied into the tree by `apply_patches.sh`. |
| `build_files/android/patches/player_entrypoint/` | `android_main_wrapper.cc` + a CMake fragment that builds the player as a shared object on Android. |
| `build_files/android/patches/oidn_android.diff`, `glog_android.diff` | Reference patches Wanderson carries for the `full` feature set. Not applied in current recipes. |
| `build_files/android/apk/` | APK skeleton: `AndroidManifest.xml`, `MainActivity.java`, `strings.xml`. |
| `build_files/android/debug.sh` | Read / write `blender_args.txt`, follow logcat, dump crash buffer. |
| `build_files/android/deploy.sh` | Install, run, capture log + screenshot. |
| `scripts/fetch_upbge.sh` | Clone UPBGE master, update submodules, apply patches. |
| `scripts/apply_patches.sh` | Idempotent: apply every text patch + copy new files. `--reset` reverts. |
| `scripts/package_player.sh` | Assemble the stage directory and the unsigned APK (if `aapt2` is present). |
| `scripts/verify_build.py` | Sanity-check: ELF type, exported `android_main`, payload zip, manifest. |
| `Makefile` | Convenience wrapper: `setup-host`, `setup-sdk`, `setup`, `deps`, `build`, `package`, `deploy`, `verify`, `clean-build`, `clean-all`. |
| `Dockerfile` | Reproducible build image. Mount `BUILD_BASE` as a volume to keep the deps prefix. |
| `.github/workflows/build-android.yml` | CI: single target (arm64-v8a + player-only), deps cache, artifact upload, GitHub Release on tag. |

## Data flow: source → device

1. **Source checkout.** `scripts/fetch_upbge.sh` clones UPBGE master (shallow,
   with submodules) into `$UPBGE_SOURCE`, then calls
   `scripts/apply_patches.sh`.

2. **Patches applied.** `apply_patches.sh` runs `patch -p1` with the
   `0001-GHOST-Android-minimal-backend.patch` text diff and copies the new
   `GHOST_SystemAndroid.cc`, `GHOST_WindowAndroid.cc`, `GHOST_AndroidMain.cc`,
   `android_main_wrapper.cc` files into the right places. It also renames
   `int main(int argc...)` in `source/gameengine/blenderplayer/main.cc` to
   `int player_main(int argc...)` so the wrapper can call it without
   conflicting with `android_main`.

3. **Dependency prefix.** `deps/build.sh` cross-compiles every library into
   `$BUILD_BASE/lib/android_<arch>`. This prefix is searched by CMake via
   `CMAKE_FIND_ROOT_PATH` from the toolchain file.

4. **Host code generators.** UPBGE's `makesdna` / `makesrna` generate C
   headers from `*.dna` / `*.rna` definitions; these must run on the HOST
   during the build, but with the SAME feature set as the target. `build.py`
   builds them in `$BUILD_BASE/build_host_tools_<feature>/`.

5. **Target build.** `build.py` configures
   `$BUILD_BASE/build_android_<feature>_<arch>/` with the Android toolchain,
   then `ninja blenderplayer` produces `bin/libupbgeplayer.so` (a PIE shared
   object — on Android the player is a `.so` loaded by the glue, not an ELF
   executable).

6. **Packaging.** `scripts/package_player.sh` assembles a stage directory
   containing:
   - `lib/<arch>/libupbgeplayer.so`
   - `assets/blender_runtime.zip` (UPBGE `release/datafiles`, `release/scripts`,
     the Python stdlib from the deps prefix)
   - `assets/game.blend` (placeholder for the add-on to overwrite)
   - `assets/blender_args.txt` (default `-w` to start windowed)
   - `AndroidManifest.xml`, `MainActivity.java`, `strings.xml`

   If `aapt2` is available, it links these into `build/upbge-player-unsigned.apk`.

7. **Archive.** `build.py` tars the stage into
   `$BUILD_BASE/apk/player_bundle_<feature>_<arch>.tar.gz` and symlinks
   `-latest`. The future add-on consumes this tarball.

8. **Verification.** `scripts/verify_build.py` checks the bundle for ELF type,
   exported `android_main` symbol, payload zip integrity, and manifest
   correctness.

9. **Deploy.** `build_files/android/deploy.sh` installs the unsigned APK on a
   device (after the add-on signs it), launches `MainActivity`, captures
   logcat and a screenshot.

## Why the player is a `.so`, not an executable

Android does not ship with a `main()`-style entry point. The
`android_native_app_glue` defines `void android_main(struct android_app*)`,
which the loader calls from a dedicated thread. To plug UPBGE's existing
`int main(int argc, char**)` into this shape, the patch renames it to
`player_main()` and `android_main_wrapper.cc`:

1. Synthesizes an `argv` from `blender_args.txt`.
2. Spawns a detached pthread that runs `player_main(argc, argv)`.
3. Calls `ghost_android_main(app)` on the main thread, which builds the
   `GHOST_SystemAndroid`, registers the glue callbacks, and runs the GHOST
   event loop until `app->destroyRequested`.

So the "executable" is actually `libupbgeplayer.so`, and `android_main` is
the symbol the glue looks up at process start.

## Why a "minimum viable" GHOST backend

Wanderson's fork carries ~300 Android-specific changes that make the **Blender
editor** usable on a touchscreen: on-screen keyboard, three-finger gestures,
stylus pressure normalization, modifier wheel, soft-keyboard bridge, etc.

None of that helps the `blenderplayer` runtime: a game has its own input
logic through logic bricks / Python controllers, and the editor chrome is
never shown. This system therefore ships a *minimal* GHOST backend that
maps:

- touch down/up → GHOST button down/up (left button)
- touch motion → GHOST cursor move
- BACK key → Esc
- native window created/destroyed → GHOST window create/destroy

That is enough for the player to boot a `.blend`, open a Vulkan surface, and
let the game engine's own input handlers take over. If you later want the
full Wanderson UX, port the corresponding files from his fork into
`build_files/android/patches/ghost_android/` and re-apply.

## Build directory layout

```
$BUILD_BASE/
├── lib/
│   └── android_arm64-v8a/         # deps prefix (only target ABI)
│       ├── include/...
│       └── lib/*.a *.so
├── deps_src/arm64-v8a/            # extracted tarballs
├── deps_build/arm64-v8a/          # out-of-tree builds of deps
├── build_host_tools_player-only/
├── build_host_tools_full/
├── build_android_player-only_arm64-v8a/
│   └── bin/libupbgeplayer.so
├── build_android_full_arm64-v8a/
├── android_apk_stage_player-only_arm64-v8a/
├── android_apk_stage_full_arm64-v8a/
├── logs/
│   └── deps_arm64-v8a_<feature>.log
└── apk/
    ├── player_bundle_player-only_arm64-v8a.tar.gz
    ├── player_bundle_player-only_arm64-v8a-latest.tar.gz -> ...tar.gz
    └── ...
```
