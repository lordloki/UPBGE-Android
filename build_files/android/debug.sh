#!/usr/bin/env bash
# build_files/android/debug.sh
#
# Tiny subset of Wanderson's debug.sh — reads/writes blender_args.txt in the
# app's external files dir (/sdcard/Android/data/org.upbge.player/files/),
# whose whitespace-separated flags android_main() passes to the player before
# `-w <game>`, and shows logcat for the player process.

set -euo pipefail
PKG="org.upbge.player"
EXT="/sdcard/Android/data/$PKG/files"

cmd_status() {
    adb shell pidof "$PKG" || echo "not running"
    echo "--- args file ---"
    adb shell cat "$EXT/blender_args.txt" 2>/dev/null || echo "(no args file)"
}

cmd_on() {
    local flags="$*"
    adb shell mkdir -p "$EXT"
    adb shell "echo '$flags' > $EXT/blender_args.txt"
    adb shell am force-stop "$PKG"
    adb shell am start -n "$PKG/android.app.NativeActivity"
}

cmd_off() {
    adb shell rm -f "$EXT/blender_args.txt"
    adb shell am force-stop "$PKG"
}

cmd_log() {
    adb logcat -s UPBGE:V DEBUG:V
}

cmd_crash() {
    adb logcat -d -b crash | tail -80
}

case "${1:-status}" in
    status)  cmd_status;;
    on)
        shift
        cmd_on "$*";;
    off)     cmd_off;;
    log)     cmd_log;;
    crash)   cmd_crash;;
    *) echo "usage: debug.sh {status|on 'flags'|off|log|crash}"; exit 2;;
esac
