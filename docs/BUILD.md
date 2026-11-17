# BUILD.md — How to build the UPBGE player for Android

This guide walks you through building the `blenderplayer` standalone binary
for Android `arm64-v8a` from a Linux host, end to end.

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
| openSUSE Tumbleweed | zypper | gcc14 / clang17 (default repo) |
| openSUSE Leap 15.5+ | zypper | gcc14 from `devel:gcc` repo (added automatically) |
| Fedora 39+, Rocky 9, Alma 9, RHEL 9 | dnf | gcc / clang (system default) |

It also wires up `update-alternatives` so `/usr/bin/gcc` and `/usr/bin/clang`
point at the right versions, and prints the `JAVA_HOME` / `PATH` exports you
need to add to `~/.bashrc`.

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
applies every patch under `build_files/android/patches/` plus copies the new
GHOST Android backend and player entrypoint wrapper into the tree.

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
make deps ARCH=arm64-v8a FEATURE=player-only
```

This builds ~50 libraries (player-only) or ~73 (full) into
`~/upbge_android_build_base/lib/android_<arch>/`.

Logs land in `~/upbge_android_build_base/logs/deps_<arch>_<feature>.log`.
Inspect them when a recipe fails.

The `full` feature set additionally builds TBB, OpenVDB, OIDN, OpenImageIO,
OpenSubdiv, Embree, Ceres, OpenPGL, Manifold, Draco, USD, Alembic, MaterialX.
Recipes for these are stubs in `build_files/android/deps/recipes/` and need
to be filled in before `make deps FEATURE=full` works end to end — see the
`README.md` in that directory for the contract.

## 6. Build the player

```bash
make build-player ARCH=arm64-v8a
```

This:

1. Builds the host code generators (`makesdna`, `makesrna`, ...) with the
   `player-only` feature set, so the generated RNA and DNA match the target
   binary.
2. Configures the target build with `build_files/android/toolchain/android.toolchain.cmake`.
3. Builds `blenderplayer` as a shared library (`libupbgeplayer.so`).

Output: `~/upbge_android_build_base/build_android_player-only_<arch>/bin/libupbgeplayer.so`.

## 7. Package the player bundle

```bash
make package ARCH=arm64-v8a FEATURE=player-only
```

This produces:

- `~/upbge_android_build_base/android_apk_stage_player-only_arm64-v8a/`
  containing:
  - `lib/arm64-v8a/libupbgeplayer.so`
  - `assets/blender_runtime.zip`  (scripts + datafiles + Python stdlib)
  - `assets/game.blend`           (placeholder, the add-on replaces it)
  - `assets/blender_args.txt`
  - `AndroidManifest.xml`
  - `src/main/java/org/upbge/player/MainActivity.java`
  - `src/main/res/values/strings.xml`
  - `PACKAGE_README.txt`
  - `build/upbge-player-unsigned.apk` (if `aapt2` is available)
- `~/upbge_android_build_base/apk/player_bundle_player-only_arm64-v8a-latest.tar.gz`

`scripts/verify_build.py` runs automatically and confirms:

- the `.so` is an ELF shared object of the right machine type
- `android_main` is exported as a symbol
- the runtime zip contains `datafiles/` and `scripts/`
- the manifest references `org.upbge.player`

## 8. (Optional) Install and run on a device

With a phone connected over USB or wireless ADB:

```bash
make deploy ARCH=arm64-v8a FEATURE=player-only
```

This installs the unsigned APK (you may need `adb root` on a userdebug image,
or sign the APK first), launches `MainActivity`, captures 10 s of logcat to
`./upbge.log`, and saves a screenshot to `./upbge.png`.

To debug live:

```bash
build_files/android/debug.sh status
build_files/android/debug.sh on -- --debug-wm --log wm.*
build_files/android/debug.sh log
build_files/android/debug.sh crash
```

## 9. The "four silent traps" Wanderson warns about

These all produce a green build that runs old code. Memorise them:

1. **The fast path only swaps `libblender.so`.**
   A Python, keymap, datafile or manifest change requires `--repackage`.
   `make package` does this for you.

2. **A version or DNA change needs `--reconfigure`.**
   The fast path does not rebuild the host generators, so `makesdna` and
   `makesrna` keep whatever build they had and the generated DNA / RNA disagree
   with the binary. Pass `--reconfigure` after a DNA header bump.

3. **The device unpacks the runtime once.**
   `BlenderActivity` writes a marker into its data dir and returns early while
   it exists. The marker now carries a hash of the payload (see
   `scripts/package_player.sh`), so a changed payload invalidates it. If you
   suspect a stale payload: `adb shell pm clear org.upbge.player`.

4. **`find_package(JPEG)` errors lie.**
   The build picks the wrong prefix if there is an abandoned
   `lib/android_arm64` elsewhere under the search path. Read the
   `Android LIBDIR =` line the configure step prints before believing a
   missing-dependency error. Pass `--build-base` to be explicit.

## 10. CI

`.github/workflows/build-android.yml` runs the entire pipeline on every push
to `main` and every `v*` tag, with a 1×2 matrix: `(arm64-v8a) ×
(player-only, full)`. The dependency prefix is cached per `(arch, feature)`
so subsequent runs take ~30 min instead of hours. Artifacts are kept 30 days;
tagged builds also publish a GitHub Release.
