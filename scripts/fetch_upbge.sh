#!/usr/bin/env bash
# scripts/fetch_upbge.sh
#
# Clone UPBGE master (shallow) into $UPBGE_SOURCE and apply the Android patches.
# Re-entrant: if the checkout already exists, just `git pull` instead of
# re-cloning.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/build_files/android/env.sh"

BRANCH="${UPBGE_BRANCH:-master}"
REMOTE="${UPBGE_REMOTE:-https://github.com/UPBGE/upbge.git}"
SRC="${UPBGE_SOURCE:?UPBGE_SOURCE is not set}"

RESET=0
while [ $# -gt 0 ]; do
    case "$1" in
        --reset) RESET=1; shift;;
        -h|--help)
            echo "usage: fetch_upbge.sh [--reset]"
            echo "  --reset   remove \$UPBGE_SOURCE and re-clone"
            exit 0;;
        *) echo "unknown arg: $1" >&2; exit 2;;
    esac
done

if [ "$RESET" -eq 1 ] && [ -d "$SRC" ]; then
    echo "[fetch_upbge] --reset: removing $SRC"
    rm -rf "$SRC"
fi

if [ ! -d "$SRC/.git" ]; then
    echo "[fetch_upbge] cloning $REMOTE ($BRANCH) into $SRC"
    mkdir -p "$(dirname "$SRC")"
    git clone --depth 50 --branch "$BRANCH" "$REMOTE" "$SRC"
    git -C "$SRC" submodule update --init --recursive --depth 1
else
    echo "[fetch_upbge] updating existing checkout at $SRC"
    git -C "$SRC" fetch --depth 50 origin "$BRANCH"
    git -C "$SRC" checkout "$BRANCH"
    git -C "$SRC" reset --hard "origin/$BRANCH"
    git -C "$SRC" submodule update --init --recursive --depth 1
fi

# Record the exact commit so the player bundle can carry it.
git -C "$SRC" rev-parse HEAD > "$SRC/.upbge_commit"
git -C "$SRC" describe --tags --always >> "$SRC/.upbge_commit" || true
echo "[fetch_upbge] HEAD: $(cat "$SRC/.upbge_commit" | head -1)"

# Apply the Android patches on top.
"$ROOT/scripts/apply_patches.sh"
