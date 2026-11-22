# BUILD.md — How to build the UPBGE player for Android

This guide walks you through building the `blenderplayer` standalone binary
for Android `arm64-v8a` from a Linux host, end to end.

### CPython link failure: `undefined symbol: libintl_*`

The Android gettext runtime must be built before CPython. The Python recipe checks
for `libintl.a` in `$DEPS_PREFIX/lib` and passes `-lintl` through `LIBS` when
configuring the target interpreter. If the check fails, inspect the gettext recipe
and its build log before retrying Python.

The `clang-17` linker shown in this error is the compiler driver supplied by NDK
r26d for the Android target. It is separate from the Clang 19 compiler used on
the openSUSE host.

## 1. Clone this system

First get the build system itself — every other step runs from inside it.

```bash
git clone <this-repo> upbge_android_build
cd upbge_android_build
```

You only need `git` installed on the host at this point; everything else is
installed by the next step.

## 2. Host prerequisites (Ubuntu, Debian, openSUSE, Fedora)

From inside the cloned repo, run:

```bash
make setup-host
# or:
scripts/setup_host.sh
```

The `scripts/setup_host.sh` helper detects your distro via `/etc/os-release`
and installs the right set of packages with the right package manager:

| Distro | PackageManager | Host compiler |
| --- | --- | --- |
| Ubuntu 22.04 / 24.04, Debian 12+ | apt | gcc-14 / clang-17 |
| openSUSE Tumbleweed | zypper | Clang 19 (`clang-19` / `clang++-19`), gcc14 available |
| openSUSE Leap 15.5+ | zypper | gcc14 from `devel:gcc` repo (added automatically) |
| Fedora 39+, Rocky 9, Alma 9, RHEL 9 | dnf | gcc / clang (system default) |

On openSUSE Tumbleweed it installs Clang 19 and selects it explicitly for
this build through `HOST_CC` and `HOST_CXX`; it does not change the system-wide
`clang` alternative. The script also prints the `JAVA_HOME` / `PATH` exports
you need to add to `~/.bashrc`.

To preview what it would run without touching anything:

```bash
scripts/setup_host.sh --dry-run
```

Disk: ~60 GB free for the dependency prefix + build trees + archived APKs.

macOS: not handled by `setup_host.sh`. Install Xcode Command Line Tools,
Homebrew's `clang-17`, `cmake`, `ninja`, `openjdk@17`, `python@3.11` by
hand. Windows: use WSL2 (Ubuntu inside Windows) and run `make setup-host`
there — keep the checkout inside the WSL filesystem, not `/mnt/c/...`.

## 3. Android SDK + NDK r26d

Still from inside the repo, run:

```bash
make setup-sdk
# or:
scripts/install_android_sdk.sh
```

The `scripts/install_android_sdk.sh` helper downloads the official Android
command-line tools, accepts the SDK licenses, and installs:

- `platform-tools` (adb)
- `platforms;android-34`
- `build-tools;34.0.0`
- `ndk;r26d`

It is idempotent — re-run only installs what is missing.

After it finishes, add these to `~/.bashrc` (the script prints them too):

```bash
export ANDROID_HOME=$HOME/Android/Sdk
export ANDROID_NDK_VERSION=r26d
export ANDROID_NDK_HOME=$ANDROID_HOME/ndk/$ANDROID_NDK_VERSION
export ANDROID_NDK_ROOT=$ANDROID_NDK_HOME
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64   # Ubuntu/Debian
# or: /usr/lib64/jvm/java-17-openjdk                   # openSUSE
# or: /usr/lib/jvm/java-17-openjdk                     # Fedora
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_NDK_HOME:$PATH"
```

Then `source ~/.bashrc` (or open a new shell) so the variables are visible
to the next steps.

`build_files/android/env.sh` reads all of these when sourced, so every
`make *` target picks them up automatically.

## 4. Fetch UPBGE source and apply Android patches

```bash
make setup                # or: bash scripts/fetch_upbge.sh
```

This clones UPBGE master into `~/upbge_src` (shallow), updates submodules, and
applies `build_files/android/patches/upbge/*.patch`: the Vulkan Android
surface and pre-rotation (Blender-owned files, hunks marked `UPBGE - Android`)
and the Android player backend (`source/gameengine/GamePlayer/android/`).

To re-apply patches after a `git pull` inside `~/upbge_src`:

```bash
bash scripts/apply_patches.sh
```

To start over:

```bash
bash scripts/fetch_upbge.sh --reset
```

## 5. Cross-compile the dependency prefix (one-time, hours)

```bash
make deps ARCH=arm64-v8a
```

This builds the 38 libraries listed in `docs/DEPENDENCIES.md` into
`~/upbge_android_build_base/lib/android_<arch>/`.

Logs land in `~/upbge_android_build_base/logs/deps_<arch>.log`; on failure the
last 40 lines are printed. Completed recipes are stamped and skipped on the
next run, so re-running `make deps` resumes at the recipe that failed:

```bash
make deps DEPS_ARGS="--only ffmpeg"   # rebuild a single recipe
make deps DEPS_ARGS="--force"         # rebuild everything
```

A stamp is invalidated automatically when the recipe, `_helpers.sh` or the
toolchain file changes. Everything installs into `lib/` (never `lib64/`, even
with openSUSE's `CONFIG_SITE`), and CMake 4.x is supported.

## 6. Build the player

```bash
make build ARCH=arm64-v8a
```

This:

1. Configures the same UPBGE tree for the host with the `player-only`
   feature cache and builds only `makesdna`, `makesrna`, `datatoc` and
   `shader_tool`, so the generated DNA/RNA/shader code matches the target.
   This step needs the libraries of a desktop UPBGE build. By default it uses
   Blender's precompiled `lib/linux_x64` of the UPBGE checkout, which
   `make setup` fetches with `build_files/utils/make_update.py --no-blender`
   (git-lfs, a few GB, once; `make update` would also pull the patched
   source tree).
   `HOST_LIBDIR=/path/lib/linux_x64` reuses another checkout of the same UPBGE
   revision; `HOST_LIBDIR=system` uses distribution packages instead
   (Python 3.13, oneTBB, OpenImageIO, OpenColorIO, ...). Packaging also uses that `python3.13` to precompile the standard
   library into `python313.zip` (set `HOST_PYTHON` to pick another one).
2. Configures the target build with the NDK toolchain, the same feature cache
   and `build_files/android/cmake/upbge_android_project.cmake`, which swaps in
   the host generators and completes the static link.
3. Builds `blenderplayer`: on Android a shared library, `libupbgeplayer.so`.
4. Packages and signs the APK (next section).

Both configures use `WITH_STRICT_BUILD_OPTIONS`: a missing library fails the
configure that lacks it instead of quietly disabling a feature on one side.

Output: `~/upbge_android_build_base/build_android_player-only_<arch>/bin/libupbgeplayer.so`.

## 7. Package the APK

`make build` already packages. After changing only assets or the game:

```bash
make package ARCH=arm64-v8a                  # re-package the last build
python3 build_files/android/build.py player-only --repackage --blend mygame.blend
```

This produces `~/upbge_android_build_base/android_apk_stage_player-only_arm64-v8a/`:

- `lib/arm64-v8a/libupbgeplayer.so` (stripped)
- `assets/game.blend` (`--blend`, or a placeholder the add-on replaces)
- `assets/upbge/` resources (the Python stdlib as a precompiled, uncompressed
  `python/lib/python313.zip`) and `assets/upbge/files.txt`, the extraction
  manifest (stamp + file list)
- `AndroidManifest.xml`, `res/`, `PACKAGE_README.txt`, `upbge_commit.txt`
- `upbge-player-player-only-arm64-v8a.apk`, built with `aapt2`, `zipalign`
  and `apksigner` from the newest SDK build-tools and signed with
  `~/.android/debug.keystore` (created if missing)

and archives the APK as
`~/upbge_android_build_base/apk/upbge-player-player-only-arm64-v8a-latest.apk`.

`scripts/verify_build.py` (run by `make package`) confirms:

- the `.so` is an ELF shared object of the right machine type
- `ANativeActivity_onCreate` is exported
- every file in `files.txt` exists, including the OCIO config and the stdlib
- the manifest declares `android.app.NativeActivity` with `lib_name` `upbgeplayer`

## 8. (Optional) Install and run on a device

With a phone connected over USB or wireless ADB:

```bash
make deploy ARCH=arm64-v8a
```

This installs the latest APK, launches `android.app.NativeActivity`,
captures 10 s of logcat (tag `UPBGE`: the player's stdout/stderr) to
`./upbge.log`, and saves a screenshot to `./upbge.png`.

To debug live:

```bash
build_files/android/debug.sh status
build_files/android/debug.sh on '-g show_framerate=1'
build_files/android/debug.sh log
build_files/android/debug.sh crash
```

Lifecycle (v1): leaving the app (Home, app switch, screen off) destroys the
window and ends the game; the next launch starts it again.

## 9. The "four silent traps" Wanderson warns about

These all produce a green build that runs old code. Memorise them:

1. **Assets are not rebuilt by ninja.**
   A Python, datafile, manifest or game change requires `--repackage`
   (`make package`).

2. **A version or DNA change needs `--reconfigure`.**
   The fast path does not rebuild the host generators, so `makesdna` and
   `makesrna` keep whatever build they had and the generated DNA / RNA disagree
   with the binary. Pass `--reconfigure` after a DNA header bump.

3. **The device unpacks the resources once.**
   `android_main()` keeps a copy of `assets/upbge/files.txt` and skips the
   extraction while it matches. The stamp line hashes every packaged file's
   size and mtime, so a changed asset re-extracts. If you suspect a stale
   install: `adb shell pm clear org.upbge.player`.

4. **`find_package(JPEG)` errors lie.**
   The build picks the wrong prefix if there is an abandoned
   `lib/android_arm64` elsewhere under the search path. Read the
   `[upbge-android] ... ROOT=` line the configure step prints before believing
   a missing-dependency error. Pass `--build-base` to be explicit.

## 10. CI

`.github/workflows/build-android.yml` runs the entire pipeline on every push
to `main` and every `v*` tag, single target (arm64-v8a + player-only).
The dependency prefix is cached per commit hash of every recipe file
so subsequent runs take ~30 min instead of hours. Artifacts are kept 30 days;
tagged builds also publish a GitHub Release.
