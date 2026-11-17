#!/usr/bin/env python3
"""
scripts/verify_build.py

Sanity-check the produced player bundle:
  - lib/<arch>/libupbgeplayer.so exists and is non-empty
  - it is an ELF shared object (PIE) with the right machine type
  - assets/blender_runtime.zip exists and is a valid zip
  - AndroidManifest.xml is present and references the right package
  - assets/game.blend placeholder is present (the add-on replaces it)

Exit code 0 = OK, 1 = problem.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import zipfile
from pathlib import Path

ARCH_MACHINE = {
    "arm64-v8a":    "AArch64",
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
        # nm / readelf: make sure android_main is exported.
        try:
            out = run(["nm", "-D", "--defined-only", str(lib)])
            if "android_main" not in out:
                problems.append("symbol `android_main` is not exported from libupbgeplayer.so "
                                "(the player wrapper did not link correctly)")
            else:
                if verbose: print("  symbol android_main: OK")
        except FileNotFoundError:
            if verbose: print("  (nm not installed; skipping symbol check)")

    # --- runtime payload -----------------------------------------------------
    payload = stage / "assets" / "blender_runtime.zip"
    if not payload.exists():
        problems.append(f"missing runtime payload: {payload}")
    else:
        try:
            with zipfile.ZipFile(payload) as z:
                names = z.namelist()
                if verbose: print(f"  payload entries: {len(names)}")
                if not any("datafiles" in n for n in names):
                    problems.append("payload has no release/datafiles/ entries")
                if not any("scripts" in n for n in names):
                    problems.append("payload has no release/scripts/ entries")
        except zipfile.BadZipFile as e:
            problems.append(f"payload is not a valid zip: {e}")

    # --- manifest ------------------------------------------------------------
    manifest = stage / "AndroidManifest.xml"
    if not manifest.exists():
        problems.append(f"missing AndroidManifest.xml: {manifest}")
    else:
        txt = manifest.read_text(errors="replace")
        if "org.upbge.player" not in txt:
            problems.append("manifest does not reference package org.upbge.player")
        if "MainActivity" not in txt:
            problems.append("manifest does not declare MainActivity")

    # --- game.blend placeholder ----------------------------------------------
    blend = stage / "assets" / "game.blend"
    if not blend.exists():
        problems.append(f"missing assets/game.blend placeholder: {blend}")

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
    return verify(Path(p.parse_args().stage), p.parse_args().arch,
                  p.parse_args().verbose)

if __name__ == "__main__":
    sys.exit(main())
