# ADDON_INTEGRATION.md

This document is for the **next** project you mentioned: a Blender add-on that
runs on any platform (Linux, macOS, Windows) and, given a `.blend` file,
produces a signed, installable Android APK containing that game + the
UPBGE `blenderplayer` runtime.

This build system produces the *runtime half* of that APK: a `player_bundle_*
.tar.gz` with the native `.so`, the Python runtime, the assets, the
AndroidManifest and the Java activity. The add-on supplies the *game half*
(`game.blend`) and signs the result.

## What the add-on consumes

For the player-only arm64-v8a bundle, download or build:

```
player_bundle_player-only_arm64-v8a.tar.gz
```

The bundle expands to:

| Path inside tarball | What it is |
| --- | --- |
| `lib/<arch>/libupbgeplayer.so` | The native runtime (PIE shared object). |
| `assets/blender_runtime.zip`   | UPBGE scripts + datafiles + Python stdlib. |
| `assets/blender_args.txt`      | Default player CLI args (`-w -g`). |
| `assets/game.blend`            | **Placeholder** — the add-on overwrites this. |
| `assets/upbge_commit.txt`      | The exact UPBGE commit the bundle was built from. |
| `AndroidManifest.xml`          | Manifest template (`org.upbge.player`). |
| `src/main/java/org/upbge/player/MainActivity.java` | The launcher activity. |
| `src/main/res/values/strings.xml` | App label (`UPBGE Player`). |
| `PACKAGE_README.txt`           | Quick reference. |
| `build/upbge-player-unsigned.apk` | Pre-assembled unsigned APK, if `aapt2` was available at build time. |

## Add-on workflow

Recommended UI flow inside Blender:

```
[Pick .blend file]
[Pick player_bundle_player-only_arm64-v8a.tar.gz]
[Edit app name (default: "My Game")]
[Edit package name (default: org.upbge.player)  -- optional]
[Pick signing key (.jks) + alias + password]
[                                          [ Build APK ]]
```

Pseudocode for the "Build APK" button:

```python
def build_apk(blend_path, bundle_path, app_name, feature, key_store,
              key_alias, key_pass):
    work = tempfile.mkdtemp()

    # 1. Extract the bundle.
    with tarfile.open(bundle_path) as t:
        t.extractall(work)

    # 2. Replace the placeholder .blend with the real game.
    #    The .blend must be packed (File > External Data > Pack All Into .blend)
    #    so the player has no external dependencies at runtime.
    shutil.copyfile(blend_path, os.path.join(work, "assets", "game.blend"))

    # 3. (Optional) Replace the app label in strings.xml.
    strings = os.path.join(work, "src", "main", "res", "values", "strings.xml")
    rewrite_app_name(strings, app_name)

    # 4. (Optional) Rename the package if the user wants a custom one.
    if rename_package:
        rename_package_in_manifest(work, new_package)

    # 5. The bundle already ships lib/arm64-v8a/libupbgeplayer.so — no merge needed.

    # 6. Re-assemble the APK with aapt2.
    apk_unsigned = os.path.join(work, "upbge-game-unsigned.apk")
    aapt2_link(work, manifest=os.path.join(work, "AndroidManifest.xml"),
               out=apk_unsigned, assets=os.path.join(work, "assets"),
               libs_dir=os.path.join(work, "lib"))

    # 7. zipalign.
    apk_aligned = apk_unsigned + ".aligned"
    subprocess.check_call(["zipalign", "-f", "-p", "4", apk_unsigned, apk_aligned])

    # 8. Sign with apksigner.
    apk_signed = os.path.join(work, "upbge-game.apk")
    subprocess.check_call([
        "apksigner", "sign",
        "--ks", key_store,
        "--ks-key-alias", key_alias,
        "--ks-pass", f"pass:{key_pass}",
        "--out", apk_signed,
        apk_aligned,
    ])

    # 9. Verify signature.
    subprocess.check_call(["apksigner", "verify", "--verbose", apk_signed])

    return apk_signed
```

## What `blender_args.txt` should contain

By default:

```
-w
-g
```

`-w` opens the player in windowed mode (matches the device window).
`-g` enables UPBGE game-engine mode (alternative to running `blenderplayer
-g` directly). If the game reads custom CLI flags, add them here.

The MainActivity loads `blender_args.txt` from `/assets/` on first start and
writes it to the app's internal data directory before launching the player.

## Renaming the package

If the user wants `com.mystudio.mygame` instead of `org.upbge.player`:

1. Edit `AndroidManifest.xml`: change `package="org.upbge.player"` and the
   `<activity android:name=".MainActivity">` line (the leading `.` is relative
   to the package).
2. Move `MainActivity.java` from `src/main/java/org/upbge/player/` to
   `src/main/java/com/mystudio/mygame/` and change its `package` declaration.
3. Run `aapt2 link` with `--rename-manifest-package com.mystudio.mygame` so
   the R class lands in the new package.

## Packing the .blend

Before shipping, ensure the .blend has **no external dependencies**:

- File → External Data → Pack All Into .blend
- File → External Data → Pack All Into .blend (yes, twice — once for
  images, once for libraries)
- Save the file with "Compress File" enabled if size matters.

The player's `game.blend` is read-only from `assets/`, so any external
referenced file must either be packed or shipped under `assets/` with the
matching relative path.

## Debugging on the device

Once installed:

```bash
adb shell am start -n org.upbge.player/.MainActivity
adb shell pidof org.upbge.player           # still alive?
adb logcat -s upbge_ghost upbge_main upbge_player_wrap blender
adb logcat -b crash | tail -80             # native tombstones
```

To pass ad-hoc flags without rebuilding the APK:

```bash
adb shell mkdir -p /sdcard/Android/data/org.upbge.player/files
adb shell 'echo --debug-wm > /sdcard/Android/data/org.upbge.player/files/blender_args.txt'
adb shell am force-stop org.upbge.player
adb shell am start -n org.upbge.player/.MainActivity
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

The `assets/upbge_commit.txt` file in every bundle records the exact UPBGE
commit; the add-on should surface this in its About dialog.
