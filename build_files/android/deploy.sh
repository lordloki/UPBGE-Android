#!/usr/bin/env bash
# build_files/android/deploy.sh
# Install, run, capture logs and a screenshot from a connected device.
set -euo pipefail
PKG="org.upbge.player"
ACTIVITY="$PKG/android.app.NativeActivity"
ARCH="${ARCH:-arm64-v8a}"

usage() {
    cat <<EOF
usage: deploy.sh [--arch ARCH] [--apk PATH] [--run] [--log SECS] [--shot]

  --arch ARCH       device ABI (default: arm64-v8a; only target supported)
  --apk PATH        explicit APK path; otherwise inferred from BUILD_BASE
  --run             start the activity after install
  --log SECS        capture SECS seconds of logcat to ./upbge.log
  --shot            capture a screenshot to ./upbge.png
EOF
}

RUN=0
LOG_SECS=0
SHOT=0
APK=""
while [ $# -gt 0 ]; do
    case "$1" in
        --arch) ARCH="$2"; shift 2;;
        --apk) APK="$2"; shift 2;;
        --run) RUN=1; shift;;
        --log) LOG_SECS="$2"; shift 2;;
        --shot) SHOT=1; shift;;
        -h|--help) usage; exit 0;;
        *) echo "unknown arg: $1" >&2; usage; exit 2;;
    esac
done

if [ -z "$APK" ]; then
    ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    . "$ROOT/build_files/android/env.sh"
    APK="$BUILD_BASE/apk/upbge-player-player-only-${ARCH}-latest.apk"
    if [ ! -f "$APK" ]; then
        echo "no APK at $APK; pass --apk explicitly" >&2
        exit 1
    fi
fi

adb devices | grep -q 'device$' || { echo "no device attached"; exit 1; }

echo "[deploy] installing $APK"
adb install -r "$APK"

if [ "$RUN" -eq 1 ]; then
    echo "[deploy] starting $ACTIVITY"
    adb shell am start -n "$ACTIVITY"
fi

if [ "$LOG_SECS" -gt 0 ]; then
    echo "[deploy] capturing $LOG_SECS s of logcat"
    # The player sends stdout/stderr (CM_Message, Python print) to the UPBGE tag.
    timeout "$LOG_SECS" adb logcat -s UPBGE:V DEBUG:V \
        > upbge.log 2>&1 || true
    echo "  -> upbge.log"
fi

if [ "$SHOT" -eq 1 ]; then
    echo "[deploy] capturing screenshot"
    adb exec-out screencap -p > upbge.png
    echo "  -> upbge.png"
fi
