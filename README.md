# UPBGE blenderplayer for Android — Build System

Cross-compile the **UPBGE `blenderplayer`** standalone binary for Android
(`arm64-v8a`) on a Linux host. The output is a self-contained
**player bundle** (native binary + minimal runtime assets + APK skeleton) that a
Blender/UPBGE add-on can later wrap together with a `.blend` file to ship a
playable Android APK.

This project is **not** a port of the full Blender editor to Android. It is the
minimum viable bring-up of the UPBGE game-engine runtime on Android, inspired by
and derived from the work of:

- **Wanderson M. Pimenta** — `blender_for_android` (https://github.com/Wanderson-Magalhaes/blender_for_android)
- **Simfeo (idimus)** — original Android alpha (https://github.com/simfeo/blender)

UPBGE itself is at https://github.com/UPBGE/upbge (branch: `master`).

## What you get

| Output | Path | Contents |
| --- | --- | --- |
| Native binary | `BUILD_BASE/build_android_<cfg>_<arch>/bin/blenderplayer` | ELF shared object (PIE), loaded by the Android glue |
| Player APK | `BUILD_BASE/apk/upbge-player-<cfg>-<arch>-latest.apk` | NativeActivity APK (debug key); the stage next to it is what the add-on wraps |
| Host codegen | `BUILD_BASE/build_host_tools_<cfg>/bin/makesdna`, `makesrna`, ... | Built with the same feature set as the target |

`<cfg>` is always `player-only`. `<arch>` is always `arm64-v8a`.

## Quickstart

```bash
# 1. Clone this system
git clone <this-repo> upbge_android_build
cd upbge_android_build

# 2. Install host prerequisites (auto-detects Ubuntu/Debian/openSUSE/Fedora)
make setup-host
#    ↑ installs host build tools; openSUSE Tumbleweed uses Clang 19.
#      prints the JAVA_HOME / ANDROID_HOME / PATH exports to add to ~/.bashrc.

# 3. Install Android SDK + NDK r26d
make setup-sdk
#    ↑ downloads commandlinetools, accepts licenses, installs platform-tools,
#      platforms;android-34, build-tools;34.0.0, ndk;r26d.

# 4. (After adding the exports to ~/.bashrc and `source ~/.bashrc`)

# 5. Fetch UPBGE source and apply the Android patches
make setup

# 6. Cross-compile the dependency prefix (one-time, ~3-6 hours)
make deps ARCH=arm64-v8a

# 7. Build the player binary
make build ARCH=arm64-v8a

# 8. Package the player bundle for your add-on
make package ARCH=arm64-v8a
```

`make setup-host` works on Ubuntu, Debian, openSUSE Tumbleweed, openSUSE
Leap (auto-adds the `devel:gcc` repo for gcc14), Fedora, Rocky, Alma, RHEL.
For macOS use Homebrew; for Windows use WSL2 and run `make setup-host` inside
the Ubuntu WSL instance.

arm64-v8a is the only target ABI; `armeabi-v7a` was considered but
dropped — every Android phone sold since ~2017 is arm64, and the build-time
RAM needed to link `libupbgeplayer.so` exceeds what a 32-bit toolchain can
address comfortably.

## Layout

```
upbge_android_build/
├── build_files/android/
│   ├── build.py              # main orchestrator
│   ├── env.sh                # environment (NDK, SDK, host compiler)
│   ├── deps/build.sh         # cross-compile dependency prefix
│   ├── deps/recipes/*.sh     # per-library recipes
│   ├── features/             # CMake feature toggles (common, player_only)
│   ├── toolchain/            # CMake toolchain for Android NDK
│   ├── patches/              # Android patches applied to UPBGE source
│   ├── apk/                  # minimal APK skeleton (manifest, activity, glue)
│   ├── debug.sh              # logcat / crash / report helper
│   └── deploy.sh             # install + run on a device
├── scripts/
│   ├── setup_host.sh         # detect distro (Ubuntu/openSUSE/Fedora) + install host prereqs
│   ├── install_android_sdk.sh # download SDK command-line tools + NDK r26d
│   ├── fetch_upbge.sh        # clone UPBGE master
│   ├── apply_patches.sh      # apply build_files/android/patches/upbge/*.patch to UPBGE
│   ├── package_player.sh     # bundle binary + assets + APK skeleton
│   └── verify_build.py       # sanity-check the produced binary
├── .github/workflows/build-android.yml   # CI matrix (feature; arm64-v8a only)
├── docs/                     # BUILD.md, ARCHITECTURE.md, DEPENDENCIES.md, ADDON_INTEGRATION.md
├── Dockerfile                # reproducible build image (optional)
├── Makefile                  # convenience wrapper around build.py
└── README.md
```

## Why "minimum viable"

Wanderson's `blender_for_android` carries hundreds of Android-specific changes:
on-screen keyboard, three-finger pan, stylus pressure normalization, modifier
wheel, soft-keyboard bridge, touch-scroll regions, file-browser single-click
default, etc. Most of that exists to make the **Blender editor** usable on a
touch screen.

This system only carries what the **`blenderplayer`** runtime needs to boot a
`.blend`, open a Vulkan surface, and pump input:

- `GHOST_SystemAndroid` minimal lifecycle (window create/destroy, focus, resize)
- `android_main` native entry that calls `BLI_main` with `-w` style args
- Touch → mouse-button / motion mapping at the GHOST level (no editor UI tweaks)
- Hard-key forwarding for back button / volume (optional)
- Vulkan surface from `ANativeWindow`

Everything else stays as upstream UPBGE. When the add-on wraps the bundle with a
game, the game logic (Python controllers, logic bricks, actuators) is what
defines the UX — not the editor chrome.

## License

UPBGE and Blender are GPL-3.0. The scripts in this repository are also GPL-3.0
to remain compatible. See `COPYING` (added by `make setup`) and `LICENSE`.

## Status

Study / bring-up project. No support is promised. The hard cross-compile work
was done by Wanderson and Simfeo; this repository adapts their approach to the
UPBGE tree. Anything that breaks here is the fault of this repository, not theirs.
