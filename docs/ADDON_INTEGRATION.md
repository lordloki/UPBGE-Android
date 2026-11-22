# ADDON_INTEGRATION.md

This document is for the **next** project you mentioned: a Blender add-on that
runs on any platform (Linux, macOS, Windows) and, given a `.blend` file,
produces a signed, installable Android APK containing that game + the
UPBGE `blenderplayer` runtime.

This build system produces the *runtime half* of that APK: the stage
directory `android_apk_stage_<feature>_<arch>/` with the native library, the
resources the player extracts on first launch and the manifest, plus a debug
signed APK. The add-on supplies the *game half* (`game.blend`) and signs the
result with the user's key.

## What the add-on consumes

| Path in the stage | What it is |
| --- | --- |
| `lib/<arch>/libupbgeplayer.so` | The player: a NativeActivity library (no Java code). |
| `assets/upbge/` | Resources copied to internal storage at first launch (`BLENDER_SYSTEM_RESOURCES`): `datafiles/` (OpenColorIO, fonts), `scripts/` (modules, startup, bge), `python/lib/python3.13`. |
| `assets/upbge/files.txt` | Extraction manifest: a stamp line, then every asset path to copy. The player re-extracts whenever this file changes. |
| `assets/game.blend` | **Placeholder** unless `build.py --blend` was used; the add-on overwrites it. |
| `AndroidManifest.xml` | `org.upbge.player`, `android.app.NativeActivity`, `android.app.lib_name=upbgeplayer`. |
| `res/values/strings.xml` | App label (`UPBGE Player`). |
| `upbge_commit.txt` | The exact UPBGE commit the library was built from. |
| `PACKAGE_README.txt` | Quick reference. |
| `upbge-player-<feature>-<arch>.apk` | Assembled APK signed with the debug key (if the SDK build-tools were found). |

## Add-on workflow

```python
def build_apk(stage, blend_path, app_name, key_store, key_alias, key_pass):
    work = tempfile.mkdtemp()
    shutil.copytree(stage, work, dirs_exist_ok=True)

    # 1. The game. Pack it first (File > External Data > Pack Resources).
    shutil.copyfile(blend_path, os.path.join(work, "assets", "game.blend"))

    # 2. Refresh the extraction manifest: the player compares it byte for
    #    byte, so a new stamp makes devices with an older install re-extract.
    regenerate_files_txt(os.path.join(work, "assets"))  # same format as package_player.sh

    # 3. Optional: app label, package name (aapt2 --rename-manifest-package).
    rewrite_app_name(os.path.join(work, "res", "values", "strings.xml"), app_name)

    # 4. aapt2 compile/link the manifest and res/, then add assets/ and lib/
    #    with a plain zip tool: `aapt2 link -A` skips directories starting with
    #    '_' (_bpy_internal, __phello__, ...).
    base = aapt2_link(work)
    zip_add(base, os.path.join(work, "assets"), os.path.join(work, "lib"))

    # 5. Align, sign, verify.
    subprocess.check_call(["zipalign", "-f", "-p", "4", base, base + ".aligned"])
    signed = os.path.join(work, "game.apk")
    subprocess.check_call(["apksigner", "sign", "--ks", key_store,
                           "--ks-key-alias", key_alias, "--ks-pass", f"pass:{key_pass}",
                           "--out", signed, base + ".aligned"])
    subprocess.check_call(["apksigner", "verify", signed])
    return signed
```

`scripts/package_player.sh --blend game.blend` does steps 1, 2, 4 and 5 with
the debug key; it is the reference implementation.

## Player arguments

The player always runs `upbgeplayer [extra flags] -w <internal>/game.blend`
(`-w`: the window is the full-screen activity surface). Extra flags for
development come from `blender_args.txt` in the app's external files
directory, whitespace separated (see `build_files/android/debug.sh`).

## Renaming the package

No Java code means nothing to move: change `package=` in
`AndroidManifest.xml` (or pass `--rename-manifest-package` to `aapt2 link`).
The activity is `android.app.NativeActivity` whatever the package.

## Packing the .blend

Before shipping, ensure the .blend has **no external dependencies**
(File → External Data → Pack Resources). The player loads `game.blend`
from internal storage; anything not packed must be shipped under `assets/`
with the matching relative path and listed in `files.txt`.

## Debugging on the device

```bash
adb shell am start -n org.upbge.player/android.app.NativeActivity
adb shell pidof org.upbge.player           # still alive?
adb logcat -s UPBGE                        # stdout/stderr of the player
adb logcat -b crash | tail -80             # native tombstones
```

To pass ad-hoc flags without rebuilding the APK:

```bash
build_files/android/debug.sh on '-g show_framerate=1'
build_files/android/debug.sh off
```

## Signing keys

For development, use a debug key:

```bash
keytool -genkeypair -keystore debug.jks -alias androiddebugkey \
    -dname "CN=Android Debug,O=Android,C=US" \
    -storepass android -keypass android -keyalg RSA -keysize 2048 \
    -validity 10000
```

For release, use Google Play App Signing:

1. Generate an upload key with `keytool`.
2. Sign APKs with `apksigner` using that key.
3. Enroll in Play App Signing so Google re-signs with the final key.

## Size considerations

| Bundle | Final APK |
| --- | --- |
| player-only arm64-v8a | ~80-100 MB |

Because the bundle ships only one ABI and one feature set, there is no "fat
APK" overhead. If you later add other ABIs (rare — arm64-v8a covers ~99% of
active Android devices), ship them as separate APKs or as an Android App
Bundle (`.aab`) so Play Store delivers only the user's device ABI:
`bundletool build-apks --bundle=upbge-game.aab`.

## GPL compliance

UPBGE and Blender are GPL-3.0. Any APK you ship that contains the
`libupbgeplayer.so` binary is a "conveyance" of GPL code, so you MUST:

1. Provide the corresponding source (UPBGE + this build system + any patches
   you applied).
2. Include the GPL license text.
3. If you modified the player or GHOST, publish those modifications.

The `upbge_commit.txt` file in every stage records the exact UPBGE commit;
the add-on should surface this in its About dialog.
