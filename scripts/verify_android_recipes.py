#!/usr/bin/env python3
"""Static checks for the active Android dependency recipe set."""

from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
BUILD_SCRIPT = ROOT / "build_files/android/deps/build.sh"
RECIPES_DIR = ROOT / "build_files/android/deps/recipes"


def main() -> int:
    source = BUILD_SCRIPT.read_text(encoding="utf-8")
    match = re.search(r"RECIPES=\((.*?)\)", source, re.DOTALL)
    if not match:
        print("Could not locate RECIPES array", file=sys.stderr)
        return 1

    names = []
    for line in match.group(1).splitlines():
        name = line.split("#", 1)[0].strip()
        if name:
            names.append(name)

    errors = []
    for name in names:
        path = RECIPES_DIR / f"{name}.sh"
        if not path.is_file():
            errors.append(f"{name}: recipe file is missing")
            continue
        text = path.read_text(encoding="utf-8")
        if not re.search(rf"\brecipe_{re.escape(name)}\s*\(\)", text):
            errors.append(f"{name}: recipe_{name}() is missing")
        if "STATUS: stub" in text:
            errors.append(f"{name}: active recipe is still marked as a stub")
        result = subprocess.run(["bash", "-n", str(path)], check=False)
        if result.returncode:
            errors.append(f"{name}: Bash syntax check failed")

    result = subprocess.run(["bash", "-n", str(BUILD_SCRIPT)], check=False)
    if result.returncode:
        errors.append("deps/build.sh: Bash syntax check failed")

    if errors:
        print("Android recipe validation failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1

    print(f"Android recipe validation passed ({len(names)} active recipes).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
