#!/usr/bin/env python3
"""
scripts/verify_build.py

Sanity-check the produced player stage (scripts/package_player.sh):
  - lib/<arch>/libupbgeplayer.so is an ELF shared object for the right machine
    and exports ANativeActivity_onCreate (the NativeActivity entry point)
  - assets/upbge/files.txt lists only files that exist, including the
    OpenColorIO config and the Python standard library
  - assets/game.blend is present (the add-on replaces the placeholder)
  - AndroidManifest.xml declares android.app.NativeActivity with
    android.app.lib_name = upbgeplayer

Exit code 0 = OK, 1 = problem.
"""

from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

ARCH_MACHINE = {
    "arm64-v8a":    "aarch64",   # file(1) prints "ARM aarch64"
    "x86_64":       "x86-64",
    "x86":          "Intel 80386",
}

def run(cmd: list[str]) -> str:
    return subprocess.check_output(cmd, text=True)

def verify(stage: Path, arch: str, verbose: bool) -> int:
    problems: list[str] = []

    # --- native lib ----------------------------------------------------------
    lib = stage / "lib" / arch / "libupbgeplayer.so"
    if not lib.exists():
        problems.append(f"missing native lib: {lib}")
    else:
        size_mb = lib.stat().st_size / (1024*1024)
        if verbose: print(f"  binary: {lib}  ({size_mb:.1f} MB)")
        if size_mb < 1.0:
            problems.append(f"binary suspiciously small: {size_mb:.2f} MB")
        # `file` tells us the ELF class + machine.
        try:
            out = run(["file", "-b", str(lib)])
            if verbose: print(f"  file: {out.strip()}")
            if "ELF" not in out:
                problems.append(f"not an ELF file: {out.strip()}")
            if "shared object" not in out:
                problems.append(f"not a shared object: {out.strip()}")
            machine = ARCH_MACHINE.get(arch, "")
            if machine and machine not in out:
                problems.append(f"wrong machine type: expected {machine}, got: {out.strip()}")
        except FileNotFoundError:
            if verbose: print("  (file(1) not installed; skipping ELF check)")
        # NativeActivity resolves ANativeActivity_onCreate with dlsym(); everything
        # else is built with hidden visibility. The host's GNU nm usually cannot
        # read AArch64 objects; prefer the NDK's llvm-nm.
        nm = "nm"
        ndk = os.environ.get("ANDROID_NDK_HOME", "")
        ndk_nm = Path(ndk) / "toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-nm"
        if ndk and ndk_nm.is_file():
            nm = str(ndk_nm)
        try:
            out = run([nm, "-D", "--defined-only", str(lib)])
            if "ANativeActivity_onCreate" not in out:
                problems.append("symbol `ANativeActivity_onCreate` is not exported from "
                                "libupbgeplayer.so (android_native_app_glue not linked in)")
            elif verbose:
                print("  symbol ANativeActivity_onCreate: OK")
        except FileNotFoundError:
            if verbose: print("  (nm not installed; skipping symbol check)")
        except subprocess.CalledProcessError as e:
            problems.append(f"{nm} could not read {lib}: rc={e.returncode}")

    # --- extraction manifest -------------------------------------------------
    assets = stage / "assets"
    files_txt = assets / "upbge" / "files.txt"
    if not files_txt.exists():
        problems.append(f"missing extraction manifest: {files_txt}")
    else:
        lines = files_txt.read_text(errors="replace").splitlines()
        if not lines or not lines[0].startswith("upbge-android "):
            problems.append("files.txt has no stamp line")
        listed = [l for l in lines[1:] if l]
        absent = [l for l in listed if not (assets / l).is_file()]
        if absent:
            problems.append(f"files.txt lists {len(absent)} missing files, e.g. {absent[0]}")
        if verbose: print(f"  assets listed: {len(listed)}")
        for required in ("upbge/datafiles/colormanagement/config.ocio", "game.blend"):
            if required not in listed:
                problems.append(f"files.txt does not list {required}")
        if not ({"upbge/python/lib/python313.zip",
                 "upbge/python/lib/python3.13/os.py"} & set(listed)):
            problems.append("files.txt lists no Python standard library")

    # --- manifest ------------------------------------------------------------
    manifest = stage / "AndroidManifest.xml"
    if not manifest.exists():
        problems.append(f"missing AndroidManifest.xml: {manifest}")
    else:
        txt = manifest.read_text(errors="replace")
        if "org.upbge.player" not in txt:
            problems.append("manifest does not reference package org.upbge.player")
        if "android.app.NativeActivity" not in txt:
            problems.append("manifest does not declare android.app.NativeActivity")
        if 'android:value="upbgeplayer"' not in txt:
            problems.append("manifest android.app.lib_name is not upbgeplayer")

    # --- game.blend placeholder ----------------------------------------------
    blend = stage / "assets" / "game.blend"
    if not blend.exists():
        problems.append(f"missing assets/game.blend: {blend}")
    elif verbose:
        # Blender writes a raw .blend, or a zstd stream when the file is saved
        # with "Compress" (zstd since 3.0): check both magics.
        with blend.open("rb") as f:
            head = f.read(7)
        if head == b"BLENDER":
            print("  game.blend: .blend")
        elif head[:4] == b"\x28\xb5\x2f\xfd":
            print("  game.blend: .blend (zstd-compressed)")
        else:
            print("  game.blend: placeholder (not a .blend yet)")

    # --- bundle readme -------------------------------------------------------
    readme = stage / "PACKAGE_README.txt"
    if not readme.exists():
        problems.append(f"missing PACKAGE_README.txt: {readme}")

    if problems:
        sys.stderr.write("verify_build: FAILED\n")
        for p in problems:
            sys.stderr.write(f"  - {p}\n")
        return 1
    print(f"verify_build: OK ({stage})")
    return 0

def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("stage", help="path to the assembled player bundle stage dir")
    p.add_argument("--arch", required=True, choices=list(ARCH_MACHINE))
    p.add_argument("-v","--verbose", action="store_true")
    args = p.parse_args()
    return verify(Path(args.stage), args.arch, args.verbose)

if __name__ == "__main__":
    sys.exit(main())
