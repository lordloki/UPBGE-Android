#!/usr/bin/env bash
# scripts/package_player.sh
#
# Assemble the player APK (normally called by build.py).
#
#   --binary PATH        libupbgeplayer.so
#   --upbge-source PATH  UPBGE checkout (scripts/, release/datafiles/)
#   --dep-prefix PATH    deps prefix (Python standard library)
#   --stage PATH         output directory (recreated)
#   --arch ARCH          arm64-v8a
#   --feature STR        player-only
#   --apk-template PATH  build_files/android/apk
#   --blend PATH         game to ship as assets/game.blend (default: placeholder)
#   --debuggable         keep symbols, mark the APK debuggable
#
# Layout under --stage:
#   AndroidManifest.xml, res/            from the template
#   lib/<arch>/libupbgeplayer.so         stripped unless --debuggable
#   assets/game.blend
#   assets/upbge/files.txt               extraction manifest, see below
#   assets/upbge/{datafiles,scripts,python}/
#                                        BLENDER_SYSTEM_RESOURCES on the device;
#                                        the stdlib is python/lib/python313.zip
#   upbge-player-<feature>-<arch>.apk    aligned, signed with the debug key
#
# files.txt: one stamp line, then every asset path the player copies to
# internal storage on first launch. The player compares the whole file with
# the copy it kept, so any change re-extracts.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BINARY=""
UPBGE_SOURCE=""
DEP_PREFIX=""
STAGE=""
FEATURE="player-only"
ARCH="arm64-v8a"
APK_TEMPLATE="$ROOT/build_files/android/apk"
BLEND=""
DEBUGGABLE=0

while [ $# -gt 0 ]; do
    case "$1" in
        --binary)       BINARY="$2"; shift 2;;
        --upbge-source) UPBGE_SOURCE="$2"; shift 2;;
        --dep-prefix)   DEP_PREFIX="$2"; shift 2;;
        --stage)        STAGE="$2"; shift 2;;
        --feature)      FEATURE="$2"; shift 2;;
        --arch)         ARCH="$2"; shift 2;;
        --apk-template) APK_TEMPLATE="$2"; shift 2;;
        --blend)        BLEND="$2"; shift 2;;
        --debuggable)   DEBUGGABLE=1; shift;;
        -h|--help)
            sed -n '2,28p' "${BASH_SOURCE[0]}"
            exit 0;;
        *) echo "unknown arg: $1" >&2; exit 2;;
    esac
done

for v in BINARY UPBGE_SOURCE DEP_PREFIX STAGE; do
    if [ -z "${!v:-}" ]; then
        echo "missing --$(echo "$v" | tr '_' '-' | tr '[:upper:]' '[:lower:]')" >&2
        exit 2
    fi
done

log() { echo "[package_player] $*"; }

PYVER=3.13  # UPBGE master (build_environment/cmake/versions.cmake)
PYLIB="$DEP_PREFIX/lib/python$PYVER"
[ -d "$PYLIB" ] || { echo "Python $PYVER standard library not found: $PYLIB" >&2; exit 1; }

log "stage=$STAGE arch=$ARCH feature=$FEATURE"
rm -rf "$STAGE"
mkdir -p "$STAGE/lib/$ARCH" "$STAGE/assets/upbge" "$STAGE/build"
RES="$STAGE/assets/upbge"

# copy_tree SRC DST [tar --exclude patterns...]
copy_tree() {
    local src="$1" dst="$2"; shift 2
    local excludes=(--exclude=__pycache__ --exclude='*.pyc')
    local pattern
    for pattern in "$@"; do
        excludes+=("--exclude=$pattern")
    done
    mkdir -p "$dst"
    tar -C "$src" "${excludes[@]}" -cf - . | tar -C "$dst" -xf -
}

# --- Native library ------------------------------------------------------------
LIB="$STAGE/lib/$ARCH/libupbgeplayer.so"
if [ "$DEBUGGABLE" -eq 1 ]; then
    cp "$BINARY" "$LIB"
else
    STRIP="${ANDROID_NDK_HOME:-}/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip"
    [ -x "$STRIP" ] || STRIP="$(command -v llvm-strip || true)"
    if [ -n "$STRIP" ]; then
        # Dynamic symbols stay: NativeActivity needs ANativeActivity_onCreate.
        "$STRIP" --strip-unneeded -o "$LIB" "$BINARY"
    else
        log "WARNING: llvm-strip not found, packaging an unstripped library"
        cp "$BINARY" "$LIB"
    fi
fi

# --- Resources (the same layout as an installed <version>/ directory) -----------
copy_tree "$UPBGE_SOURCE/release/datafiles/colormanagement" "$RES/datafiles/colormanagement"
copy_tree "$UPBGE_SOURCE/release/datafiles/fonts"           "$RES/datafiles/fonts"
for dir in modules startup bge; do
    copy_tree "$UPBGE_SOURCE/scripts/$dir" "$RES/scripts/$dir"
done
# Static interpreter: the stdlib is pure Python (no lib-dynload). Drop what a
# game never imports, plus config-3.x (the static libpython, ~50 MB).
STDLIB_TMP="$STAGE/build/python$PYVER"
copy_tree "$PYLIB" "$STDLIB_TMP" \
    "./config-$PYVER*" ./test ./idlelib ./tkinter ./turtledemo ./ensurepip ./lib2to3
# Ship it as lib/python313.zip, which CPython always puts first on sys.path:
# one asset instead of ~550 files to extract. zipimport cannot write
# __pycache__, so the bytecode is compiled here (unchecked-hash: no mtime
# check against the sources) by a host Python of the same minor version, and
# the zip is stored uncompressed (no inflate per import; the APK compresses it).
# The .py files stay for tracebacks.
PYZIP="$RES/python/lib/python${PYVER/./}.zip"
HOST_PYTHON="${HOST_PYTHON:-$(command -v "python$PYVER" || true)}"
# Distros without python3.13 (Ubuntu 24.04 ships 3.12): use the host
# interpreter the python recipe builds next to the deps prefix.
if [ -z "$HOST_PYTHON" ]; then
    host_py="$(dirname "$(dirname "$DEP_PREFIX")")/deps_build/$ARCH/python-host/bin/python$PYVER"
    [ -x "$host_py" ] && HOST_PYTHON="$host_py"
fi
if [ -n "$HOST_PYTHON" ] && command -v zip >/dev/null 2>&1 &&
   [ "$("$HOST_PYTHON" -c 'import sys; print("%d.%d" % sys.version_info[:2])')" = "$PYVER" ]; then
    "$HOST_PYTHON" -m compileall -q -b -j0 --invalidation-mode unchecked-hash \
        "$STDLIB_TMP" >/dev/null
    mkdir -p "$(dirname "$PYZIP")"
    ( cd "$STDLIB_TMP" && zip -q -0 -r -X "$PYZIP" . )
else
    log "WARNING: no host python$PYVER or zip: shipping the stdlib as files"
    mkdir -p "$RES/python/lib"
    mv "$STDLIB_TMP" "$RES/python/lib/python$PYVER"
fi

# --- Game ------------------------------------------------------------------------
if [ -n "$BLEND" ]; then
    cp "$BLEND" "$STAGE/assets/game.blend"
else
    # Not a .blend: the player fails to load it. The add-on writes the real one.
    echo "PLACEHOLDER: replace assets/game.blend with the game." > "$STAGE/assets/game.blend"
fi

# --- Extraction manifest -----------------------------------------------------------
# Sizes and mtimes of every file feed the stamp, so a changed asset changes it.
(
    cd "$STAGE/assets"
    files="$(find upbge game.blend -type f ! -path upbge/files.txt | LC_ALL=C sort)"
    stamp="$(printf '%s\n' "$files" | xargs -d '\n' stat -c '%n %s %Y' | sha1sum | cut -c1-40)"
    { echo "upbge-android $stamp"; printf '%s\n' "$files"; } > upbge/files.txt
)
log "assets: $(($(wc -l < "$RES/files.txt") - 1)) files, $(du -sh "$STAGE/assets" | cut -f1)"

# --- Manifest and resources ----------------------------------------------------------
cp "$APK_TEMPLATE/src/main/AndroidManifest.xml" "$STAGE/AndroidManifest.xml"
cp -r "$APK_TEMPLATE/src/main/res" "$STAGE/res"

# Source traceability (GPL): the exact UPBGE commit, kept outside assets/.
if [ -f "$UPBGE_SOURCE/.upbge_commit" ]; then
    cp "$UPBGE_SOURCE/.upbge_commit" "$STAGE/upbge_commit.txt"
else
    git -C "$UPBGE_SOURCE" rev-parse HEAD > "$STAGE/upbge_commit.txt" 2>/dev/null || true
fi

cat > "$STAGE/PACKAGE_README.txt" <<EOF
UPBGE player bundle ($FEATURE, $ARCH)

lib/$ARCH/libupbgeplayer.so   NativeActivity library (android.app.lib_name)
assets/game.blend            the game; replace it to ship another one
assets/upbge/                resources copied to internal storage at first run;
                             regenerate assets/upbge/files.txt after any change
                             (scripts/package_player.sh does it)

Release signing: zipalign -p -f 4 in.apk aligned.apk
                 apksigner sign --ks release.jks aligned.apk
EOF

# --- APK ---------------------------------------------------------------------------------
find_tool() {
    local name="$1" dir
    if command -v "$name" >/dev/null 2>&1; then
        command -v "$name"
        return 0
    fi
    [ -n "${ANDROID_HOME:-}" ] || return 1
    # Newest build-tools first.
    while IFS= read -r dir; do
        if [ -x "$dir/$name" ]; then
            echo "$dir/$name"
            return 0
        fi
    done < <(find "$ANDROID_HOME/build-tools" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -rV)
    return 1
}

AAPT2="$(find_tool aapt2 || true)"
ZIPALIGN="$(find_tool zipalign || true)"
APKSIGNER="$(find_tool apksigner || true)"
TARGET_API="${ANDROID_TARGET_API:-34}"
TARGET_API="${TARGET_API#android-}"
ANDROID_JAR="${ANDROID_HOME:-}/platforms/android-$TARGET_API/android.jar"

if [ -z "$AAPT2" ] || [ -z "$ZIPALIGN" ] || [ ! -f "$ANDROID_JAR" ]; then
    log "aapt2/zipalign or $ANDROID_JAR missing: stage only, no APK"
    log "done: $STAGE"
    exit 0
fi

APK_BASE="$STAGE/build/base.apk"
APK_ALIGNED="$STAGE/build/aligned.apk"
APK_OUT="$STAGE/upbge-player-$FEATURE-$ARCH.apk"
LINK_ARGS=()
[ "$DEBUGGABLE" -eq 1 ] && LINK_ARGS+=(--debug-mode)

"$AAPT2" compile --dir "$STAGE/res" -o "$STAGE/build/res.zip"
"$AAPT2" link -I "$ANDROID_JAR" --manifest "$STAGE/AndroidManifest.xml" \
    "${LINK_ARGS[@]}" -o "$APK_BASE" "$STAGE/build/res.zip"
# Assets and the library go in with zip, not `aapt2 link -A`: aapt2 skips
# directories starting with '_' (_bpy_internal, __phello__, ...) and dot files.
( cd "$STAGE" && zip -qr "$APK_BASE" assets lib )
"$ZIPALIGN" -p -f 4 "$APK_BASE" "$APK_ALIGNED"

if [ -z "$APKSIGNER" ]; then
    mv "$APK_ALIGNED" "$APK_OUT"
    log "apksigner missing: $APK_OUT is unsigned (adb install needs a signature)"
    exit 0
fi

KEYSTORE="${ANDROID_DEBUG_KEYSTORE:-$HOME/.android/debug.keystore}"
if [ ! -f "$KEYSTORE" ]; then
    KEYTOOL="${JAVA_HOME:+$JAVA_HOME/bin/}keytool"
    command -v "$KEYTOOL" >/dev/null 2>&1 || KEYTOOL=keytool
    mkdir -p "$(dirname "$KEYSTORE")"
    log "creating debug keystore $KEYSTORE"
    "$KEYTOOL" -genkeypair -keystore "$KEYSTORE" -storepass android \
        -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 \
        -validity 10000 -dname "CN=Android Debug,O=Android,C=US" >/dev/null
fi
"$APKSIGNER" sign --ks "$KEYSTORE" --ks-pass pass:android --key-pass pass:android \
    --ks-key-alias androiddebugkey --out "$APK_OUT" "$APK_ALIGNED"
log "APK: $APK_OUT (debug key)"
log "done: $STAGE"
