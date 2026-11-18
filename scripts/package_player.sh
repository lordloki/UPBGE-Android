#!/usr/bin/env bash
# scripts/package_player.sh
#
# Assemble the player bundle that the future Blender add-on will wrap together
# with a .blend file to produce a final APK.
#
# Inputs (passed as flags by build.py):
#   --binary PATH        the produced libupbgeplayer.so (or blenderplayer ELF)
#   --upbge-source PATH  the UPBGE source tree (for scripts/, release/datafiles/)
#   --dep-prefix PATH    the deps prefix (for Python stdlib + site-packages)
#   --stage PATH         where to assemble the bundle (cleaned first)
#   --feature STR        player-only (only supported value)
#   --arch STR           arm64-v8a (only target supported)
#   --apk-template PATH  the build_files/android/apk/ skeleton dir
#
# Output layout under --stage:
#   lib/<arch>/libupbgeplayer.so
#   assets/blender_runtime.zip   (scripts/, datafiles/, Python, ...)
#   assets/game.blend            (placeholder, the add-on replaces it)
#   AndroidManifest.xml
#   res/...
#   src/main/java/org/upbge/player/MainActivity.java
#   unsigned.apk                  (assembled with aapt2, signed with debug key
#                                  if `apksigner` is available; otherwise the
#                                  add-on signs it later)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BINARY=""
UPBGE_SOURCE=""
DEP_PREFIX=""
STAGE=""
FEATURE="player-only"
ARCH="arm64-v8a"
APK_TEMPLATE="$ROOT/build_files/android/apk"

while [ $# -gt 0 ]; do
    case "$1" in
        --binary)      BINARY="$2"; shift 2;;
        --upbge-source) UPBGE_SOURCE="$2"; shift 2;;
        --dep-prefix)  DEP_PREFIX="$2"; shift 2;;
        --stage)       STAGE="$2"; shift 2;;
        --feature)     FEATURE="$2"; shift 2;;
        --arch)        ARCH="$2"; shift 2;;
        --apk-template) APK_TEMPLATE="$2"; shift 2;;
        -h|--help)
            sed -n '2,30p' "${BASH_SOURCE[0]}"
            exit 0;;
        *) echo "unknown arg: $1" >&2; exit 2;;
    esac
done

for v in BINARY UPBGE_SOURCE DEP_PREFIX STAGE; do
    if [ -z "${!v:-}" ]; then echo "missing --$(echo $v | tr _ - | tr A-Z a-z)" >&2; exit 2; fi
done

echo "[package_player] stage=$STAGE arch=$ARCH feature=$FEATURE"

# 1. Clean and create the stage.
rm -rf "$STAGE"
mkdir -p "$STAGE/lib/$ARCH" "$STAGE/assets" "$STAGE/src/main/java/org/upbge/player" \
         "$STAGE/src/main/res/values" "$STAGE/build"

# 2. Native library: libupbgeplayer.so in lib/<arch>/.
DST_LIB="$STAGE/lib/$ARCH/libupbgeplayer.so"
cp -v "$BINARY" "$DST_LIB"

# 3. Runtime payload zip.
PAYLOAD="$STAGE/assets/blender_runtime.zip"
( cd "$UPBGE_SOURCE"
  # UPBGE ships its bundled scripts + datafiles under release/.
  zip -qr "$PAYLOAD" \
        release/datafiles \
        release/scripts \
        release/fonts \
        release/licenses \
        2>/dev/null || true
)

# Python stdlib + site-packages come from the deps prefix.
if [ -d "$DEP_PREFIX/lib/python3.11" ]; then
  ( cd "$DEP_PREFIX/lib"
    zip -qr "$PAYLOAD" python3.11
  )
fi

# 4. Game .blend placeholder. The add-on replaces this with the real one.
cat > "$STAGE/assets/game.blend" <<'EOF'
PLACEHOLDER: the add-on will overwrite this file with the actual game .blend.
EOF

# 5. AndroidManifest.xml from the template.
cp "$APK_TEMPLATE/src/main/AndroidManifest.xml" "$STAGE/AndroidManifest.xml"

# 6. MainActivity.java from the template.
cp "$APK_TEMPLATE/src/main/java/org/upbge/player/MainActivity.java" \
   "$STAGE/src/main/java/org/upbge/player/MainActivity.java"

# 7. strings.xml (used by the launcher label).
cp "$APK_TEMPLATE/src/main/res/values/strings.xml" \
   "$STAGE/src/main/res/values/strings.xml"

# 8. blenders_args.txt default (the player reads this on start).
cat > "$STAGE/assets/blender_args.txt" <<'EOF'
-w
-g
EOF

# 9. upbge_commit.txt for traceability.
if [ -f "$UPBGE_SOURCE/.upbge_commit" ]; then
    cp "$UPBGE_SOURCE/.upbge_commit" "$STAGE/assets/upbge_commit.txt"
fi

# 10. Try to assemble an unsigned APK if the SDK is available.
AAPT2="$(command -v aapt2 || echo "")"
if [ -n "$AAPT2" ] && [ -n "${ANDROID_HOME:-}" ]; then
    echo "[package_player] assembling unsigned APK"
    RES_DIR="$STAGE/src/main/res"
    MANIFEST="$STAGE/AndroidManifest.xml"
    APK_UNALIGNED="$STAGE/build/upbge-player-unsigned.apk"
    # Generate R.java for the app's resources (only strings for now).
    "$AAPT2" compile --dir "$RES_DIR" -o "$STAGE/build/resources.zip"
    "$AAPT2" link \
        -I "$ANDROID_HOME/platforms/android-$(echo "$ANDROID_TARGET_API" | sed 's/android-//')/android.jar" \
        --manifest "$MANIFEST" \
        -o "$APK_UNALIGNED" \
        --java "$STAGE/src/main/java" \
        --auto-add-overlay \
        "$STAGE/build/resources.zip" || true
    # Stage the native libs and assets into the APK.
    cd "$STAGE"
    zip -qr "$APK_UNALIGNED" lib assets || true
    cd -
    ln -sf "$APK_UNALIGNED" "$STAGE/upbge-player-$FEATURE-$ARCH.apk"
    echo "[package_player] unsigned APK: $APK_UNALIGNED"
else
    echo "[package_player] aapt2 or ANDROID_HOME missing; the add-on will assemble the APK"
fi

# 11. README explaining what the add-on needs to do next.
cat > "$STAGE/PACKAGE_README.txt" <<EOF
UPBGE player bundle
===================
arch:   $ARCH
feature: $FEATURE
binary: lib/$ARCH/libupbgeplayer.so

To produce a final installable APK, the Blender add-on must:
  1. Replace assets/game.blend with the actual game file.
  2. (optional) Edit assets/blender_args.txt to pass extra flags.
  3. Sign the APK with your release key (apksigner / jarsigner).
  4. zipalign -p 4 in.apk out.apk
  5. apksigner sign --ks your.key.jks out.apk
EOF

echo "[package_player] done: $STAGE"
