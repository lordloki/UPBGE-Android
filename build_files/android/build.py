#!/usr/bin/env python3
"""
build_files/android/build.py

Main orchestrator for cross-compiling the UPBGE `blenderplayer` for Android.

Usage:
    python3 build_files/android/build.py <feature> [options]

Features:
    player-only   Minimal runtime: blenderplayer + Vulkan + Python, no editor.
                  This is the only feature set supported by the system.

Options:
    --arch ARCH           arm64-v8a (only Android target supported)
    --build-base DIR      Override BUILD_BASE
    --clean               Remove the build tree before configuring
    --reconfigure         Re-run CMake, keep object files (needed after DNA change)
    --repackage           Rebuild the runtime payload zip (needed after asset change)
    --install             Push the produced APK to the connected device
    --run                 Start the app on the connected device after install
    --debuggable          Build with debug symbols and `run-as` support
    -s SERIAL             Pick a specific device when more than one is attached
    --keep N              Number of archived APKs to retain (default 5)
    --no-archive          Do not archive the produced bundle
    --jobs N              Parallel build jobs (default: nproc)
    -v, --verbose         Print every command before running it

Pipeline:
    1. Resolve environment (NDK, SDK, JDK, host compiler, BUILD_BASE).
    2. Verify the UPBGE source tree exists and the Android patches are applied.
    3. Verify the dependency prefix exists (lib/android_<arch>); if not,
       direct the user to `make deps` / deps/build.sh.
    4. Build host code generators (makesdna, makesrna, ...) with the SAME feature set.
    5. Configure the target build with the CMake toolchain and feature file.
    6. Build blenderplayer.
    7. Package: assemble the APK skeleton + assets + native binary, sign, archive.
    8. Optionally install and run on a connected device.
"""

from __future__ import annotations

import argparse
import multiprocessing
import os
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

THIS_FILE = Path(__file__).resolve()
ANDROID_DIR = THIS_FILE.parent                 # build_files/android
ROOT_DIR = ANDROID_DIR.parent.parent           # upbge_android_build/
FEATURES_DIR = ANDROID_DIR / "features"
TOOLCHAIN_FILE = ANDROID_DIR / "toolchain" / "android.toolchain.cmake"
PATCHES_DIR = ANDROID_DIR / "patches"
APK_TEMPLATE_DIR = ANDROID_DIR / "apk"

VALID_FEATURES = ("player-only",)
VALID_ARCHES = ("arm64-v8a",)

# Map ABI -> NDK CMake triplet
ARCH_TRIPLET = {
    "arm64-v8a":    "aarch64-linux-android",
}

PACKAGE_NAME = "org.upbge.player"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

class BuildError(RuntimeError):
    pass

def run(cmd: list[str], cwd: Path | None = None, env: dict | None = None,
        verbose: bool = False, check: bool = True) -> subprocess.CompletedProcess:
    if verbose:
        sys.stderr.write(f"$ {' '.join(str(c) for c in cmd)}\n")
    result = subprocess.run(cmd, cwd=str(cwd) if cwd else None,
                            env=env, text=True)
    if check and result.returncode != 0:
        raise BuildError(f"command failed (rc={result.returncode}): "
                         f"{' '.join(map(str, cmd))}")
    return result

def info(msg: str) -> None:
    sys.stderr.write(f"[build] {msg}\n")

def warn(msg: str) -> None:
    sys.stderr.write(f"[build] WARNING: {msg}\n")

# ---------------------------------------------------------------------------
# Environment
# ---------------------------------------------------------------------------

@dataclass
class Env:
    android_home: Path
    ndk_home: Path
    java_home: Path
    host_cc: str
    host_cxx: str
    build_base: Path
    upbge_source: Path
    android_platform: str
    android_target_api: str

def resolve_env(args: argparse.Namespace) -> Env:
    android_home = Path(os.environ.get("ANDROID_HOME", ""))
    ndk_version = os.environ.get("ANDROID_NDK_VERSION", "r26d")
    ndk_home = Path(os.environ.get("ANDROID_NDK_HOME",
                                    android_home / "ndk" / ndk_version))
    java_home = os.environ.get("JAVA_HOME", "")
    if not java_home:
        # Same probe order as env.sh: Debian/Ubuntu, openSUSE (lib64), Fedora.
        for cand in ("/usr/lib/jvm/java-17-openjdk-amd64",
                     "/usr/lib/jvm/java-17-openjdk-arm64",
                     "/usr/lib64/jvm/java-17-openjdk",
                     "/usr/lib64/jvm/java-17-openjdk-17",
                     "/usr/lib/jvm/java-17-openjdk"):
            if Path(cand).is_dir():
                java_home = cand
                break
    java_home = Path(java_home or "/usr/lib/jvm/java-17-openjdk-amd64")
    host_cc = os.environ.get("HOST_CC", "")
    host_cxx = os.environ.get("HOST_CXX", "")
    if not host_cc or not host_cxx:
        # Last-resort auto-pick a matching host compiler pair (same list as env.sh).
        for cand in ("clang-19", "clang-20", "clang-21", "clang-22", "clang-18",
                     "clang-17", "gcc-16", "gcc-15", "gcc-14", "gcc", "clang"):
            cxx = cand.replace("gcc", "g++").replace("clang", "clang++")
            cc_path = shutil.which(cand)
            cxx_path = shutil.which(cxx)
            if cc_path and cxx_path:
                host_cc = host_cc or cc_path
                host_cxx = host_cxx or cxx_path
                break
    if not host_cc or not host_cxx:
        raise BuildError("no matching HOST_CC/HOST_CXX pair found; source env.sh first")
    build_base = Path(args.build_base or os.environ.get("BUILD_BASE",
                       str(Path.home() / "upbge_android_build_base")))
    upbge_source = Path(os.environ.get("UPBGE_SOURCE",
                                        str(Path.home() / "upbge_src")))
    return Env(android_home=android_home, ndk_home=ndk_home, java_home=java_home,
               host_cc=host_cc, host_cxx=host_cxx,
               build_base=build_base, upbge_source=upbge_source,
               android_platform=os.environ.get("ANDROID_PLATFORM","android-31"),
               android_target_api=os.environ.get("ANDROID_TARGET_API","34"))

# ---------------------------------------------------------------------------
# Pipeline stages
# ---------------------------------------------------------------------------

def check_prereqs(env: Env) -> None:
    missing = []
    if not env.android_home.is_dir():
        missing.append(f"ANDROID_HOME={env.android_home} (not a directory)")
    if not env.ndk_home.is_dir():
        missing.append(f"ANDROID_NDK_HOME={env.ndk_home} (not a directory)")
    if not env.java_home.is_dir():
        missing.append(f"JAVA_HOME={env.java_home} (not a directory)")
    if not env.upbge_source.is_dir():
        missing.append(f"UPBGE_SOURCE={env.upbge_source} (run `make setup` first)")
    if not (env.upbge_source / "source" / "gameengine").is_dir():
        missing.append(f"{env.upbge_source} does not look like an UPBGE checkout "
                       "(source/gameengine/ missing)")
    if not shutil.which("cmake"):
        missing.append("cmake (not on PATH)")
    if not shutil.which("ninja"):
        missing.append("ninja (not on PATH)")
    if missing:
        sys.stderr.write("Missing prerequisites:\n")
        for m in missing:
            sys.stderr.write(f"  - {m}\n")
        raise BuildError("prerequisites not satisfied")

def check_dep_prefix(env: Env, arch: str) -> Path:
    prefix = env.build_base / "lib" / f"android_{arch}"
    if not prefix.is_dir():
        raise BuildError(
            f"dependency prefix not found: {prefix}\n"
            f"  Run: build_files/android/deps/build.sh --arch {arch}\n"
            f"  (one-time cost of a few hours)")
    # Heuristic: zlib should be there
    if not (prefix / "lib" / "libz.a").exists() and \
       not (prefix / "lib" / "libz.so").exists():
        warn(f"{prefix} exists but has no libz; the prefix may be incomplete "
             "(a previous deps build may have failed). Check deps/build.log.")
    return prefix

def build_host_tools(env: Env, feature: str, verbose: bool, jobs: int) -> Path:
    """Host code generators. MUST use the same feature set as the target."""
    host_build = env.build_base / f"build_host_tools_{feature}"
    host_install = host_build  # in-tree; makesdna/makesrna are run from build dir
    cmake_cache = host_build / "CMakeCache.txt"

    if cmake_cache.is_file():
        cache_text = cmake_cache.read_text(errors="replace")
        cached_cc = next((line.split("=", 1)[1] for line in cache_text.splitlines()
                          if line.startswith("CMAKE_C_COMPILER:") and "=" in line), "")
        cached_cxx = next((line.split("=", 1)[1] for line in cache_text.splitlines()
                           if line.startswith("CMAKE_CXX_COMPILER:") and "=" in line), "")
        selected_cc = str(Path(env.host_cc).resolve())
        selected_cxx = str(Path(env.host_cxx).resolve())
        if cached_cc and cached_cxx and (
                str(Path(cached_cc).resolve()) != selected_cc or
                str(Path(cached_cxx).resolve()) != selected_cxx):
            info("Host compiler changed; removing the old host-tools CMake cache")
            shutil.rmtree(host_build)

    feature_file = FEATURES_DIR / f"{feature.replace('-', '_')}.cmake"
    if not feature_file.is_file():
        raise BuildError(f"feature file missing: {feature_file}")

    if not cmake_cache.exists() or args_reconfigure:
        host_build.mkdir(parents=True, exist_ok=True)
        cmd = [
            "cmake", "-G", "Ninja",
            f"-DCMAKE_BUILD_TYPE=Release",
            f"-DCMAKE_C_COMPILER={env.host_cc}",
            f"-DCMAKE_CXX_COMPILER={env.host_cxx}",
            f"-DCMAKE_MAKE_PROGRAM=ninja",
            f"-C", str(feature_file),
            "-DWITH_ANDROID=ON",
            "-DWITH_HOST_TOOLS_ONLY=ON",
            str(env.upbge_source),
        ]
        run(cmd, cwd=host_build, verbose=verbose)
    # makesdna/makesrna are the only code generators UPBGE master has.
    run(["ninja", f"-j{jobs}", "makesdna", "makesrna"],
        cwd=host_build, verbose=verbose)
    return host_install

def configure_target(env: Env, arch: str, feature: str, dep_prefix: Path,
                     verbose: bool, debuggable: bool) -> Path:
    triplet = ARCH_TRIPLET[arch]
    build_dir = env.build_base / f"build_android_{feature}_{arch}"
    feature_file = FEATURES_DIR / f"{feature.replace('-', '_')}.cmake"
    cmake_cache = build_dir / "CMakeCache.txt"

    if args_clean and build_dir.exists():
        info(f"--clean: removing {build_dir}")
        shutil.rmtree(build_dir)

    if not cmake_cache.exists() or args_reconfigure or args_clean:
        build_dir.mkdir(parents=True, exist_ok=True)
        cmd = [
            "cmake", "-G", "Ninja",
            f"-DCMAKE_TOOLCHAIN_FILE={TOOLCHAIN_FILE}",
            f"-DANDROID_ABI={arch}",
            f"-DANDROID_PLATFORM={env.android_platform}",
            f"-DANDROID_NDK={env.ndk_home}",
            f"-DCMAKE_BUILD_TYPE={'RelWithDebInfo' if debuggable else 'Release'}",
            f"-DCMAKE_MAKE_PROGRAM=ninja",
            f"-DCMAKE_FIND_ROOT_PATH={dep_prefix}",
            f"-DANDROID_LIBDIR={dep_prefix}",
            f"-DBUILD_BASE={env.build_base}",
            f"-DUPBGE_ANDROID_ROOT={ROOT_DIR}",
            "-C", str(feature_file),
            "-DWITH_ANDROID=ON",
            "-DWITH_PLAYER=ON",
            "-DWITH_PYTHON=ON",
            "-DWITH_PYTHON_INSTALL=ON",
            "-DWITH_GPU_DEBUG=OFF",
            f"-DUPBGE_HOST_TOOLS_BUILD={env.build_base}/build_host_tools_{feature}",
            str(env.upbge_source),
        ]
        run(cmd, cwd=build_dir, verbose=verbose)
    return build_dir

def build_target(env: Env, build_dir: Path, arch: str, feature: str,
                 verbose: bool, jobs: int) -> Path:
    run(["ninja", f"-j{jobs}", "blenderplayer"], cwd=build_dir, verbose=verbose)
    binary = build_dir / "bin" / "blenderplayer"
    if not binary.exists():
        # Some CMake configs put it under source/gameengine/blenderplayer/
        alt = build_dir / "source" / "gameengine" / "blenderplayer" / "blenderplayer"
        if alt.exists():
            binary = alt
    if not binary.exists():
        raise BuildError(f"blenderplayer binary not found after build: {binary}")
    info(f"produced binary: {binary}")
    return binary

def repackage_payload(env: Env, arch: str, feature: str, binary: Path,
                      verbose: bool) -> Path:
    """Bundle scripts/, release/datafiles/, assets/ and the binary into
    blender_runtime_<cfg>_<arch>.zip — used by the APK skeleton and by the
    future add-on to ship the runtime alongside a .blend."""
    pkg = env.build_base / f"android_apk_stage_{feature}_{arch}"
    if pkg.exists():
        shutil.rmtree(pkg)
    payload_zip = pkg / "assets" / "blender_runtime.zip"
    payload_zip.parent.mkdir(parents=True, exist_ok=True)

    # Reuse the packaging helper that already knows what to include.
    script = ROOT_DIR / "scripts" / "package_player.sh"
    run(["bash", str(script),
         "--binary", str(binary),
         "--upbge-source", str(env.upbge_source),
         "--dep-prefix", str(env.build_base / "lib" / f"android_{arch}"),
         "--stage", str(pkg),
         "--feature", feature,
         "--arch", arch,
         "--apk-template", str(APK_TEMPLATE_DIR)],
        verbose=verbose)
    return pkg

def archive_bundle(env: Env, arch: str, feature: str, stage: Path,
                   keep: int, no_archive: bool) -> Path:
    archive_dir = env.build_base / "apk"
    archive_dir.mkdir(parents=True, exist_ok=True)
    tgz = archive_dir / f"player_bundle_{feature}_{arch}.tar.gz"
    if tgz.exists():
        tgz.unlink()
    run(["tar", "-czf", str(tgz),
         "-C", str(stage), "."], verbose=False)
    # Symlink latest
    latest = archive_dir / f"player_bundle_{feature}_{arch}-latest.tar.gz"
    if latest.is_symlink() or latest.exists():
        latest.unlink()
    latest.symlink_to(tgz.name)

    # Prune old archives (keep the newest `keep`)
    if not no_archive:
        archives = sorted(archive_dir.glob(f"player_bundle_{feature}_{arch}*.tar.gz"),
                          key=lambda p: p.stat().st_mtime, reverse=True)
        for old in archives[keep:]:
            old.unlink()
    info(f"archived bundle: {tgz}")
    return tgz

def install_and_run(env: Env, stage: Path, arch: str, feature: str,
                    serial: str | None, run_after: bool) -> None:
    import_re = ["-s"] if serial else []
    if serial:
        import_re += [serial]
    adb = shutil.which("adb")
    if not adb:
        raise BuildError("adb not on PATH; install Android platform-tools")
    # The package_player.sh produces a minimal unsigned APK in stage/.
    apk_files = list(stage.glob("*.apk"))
    if not apk_files:
        raise BuildError(f"no APK in {stage}; packaging failed")
    apk = apk_files[0]
    info(f"installing {apk} on device{' ('+serial+')' if serial else ''}")
    run([adb, *import_re, "install", "-r", str(apk)])
    if run_after:
        run([adb, *import_re, "shell", "am", "start", "-n",
             f"{PACKAGE_NAME}/.MainActivity"])

# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

# Module-level flags read by the stage functions (kept simple; not for reuse).
args_clean = False
args_reconfigure = False
args_repackage = False

def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description="UPBGE blenderplayer Android build orchestrator",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    p.add_argument("feature", choices=VALID_FEATURES,
                   help="which feature set to build")
    p.add_argument("--arch", choices=VALID_ARCHES, default="arm64-v8a")
    p.add_argument("--build-base", default=None)
    p.add_argument("--clean", action="store_true",
                   help="remove the build tree before configuring")
    p.add_argument("--reconfigure", action="store_true",
                   help="re-run CMake, keep object files")
    p.add_argument("--repackage", action="store_true",
                   help="rebuild the runtime payload")
    p.add_argument("--install", action="store_true", help="push APK to device")
    p.add_argument("--run", action="store_true", help="launch the app after install")
    p.add_argument("--debuggable", action="store_true",
                   help="build with debug symbols")
    p.add_argument("-s","--serial", default=None, help="adb device serial")
    p.add_argument("--keep", type=int, default=5, help="archives to keep")
    p.add_argument("--no-archive", action="store_true")
    p.add_argument("--jobs","-j", type=int, default=max(1, multiprocessing.cpu_count()))
    p.add_argument("-v","--verbose", action="store_true")
    p.add_argument("--skip-host-tools", action="store_true",
                   help="do not rebuild host tools (only safe if feature set "
                        "has not changed since last run)")
    return p.parse_args()

def main() -> int:
    global args_clean, args_reconfigure, args_repackage
    args = parse_args()
    args_clean = args.clean
    args_reconfigure = args.reconfigure
    args_repackage = args.repackage

    env = resolve_env(args)
    try:
        check_prereqs(env)
        dep_prefix = check_dep_prefix(env, args.arch)
        info(f"feature={args.feature} arch={args.arch} jobs={args.jobs}")
        if not args.skip_host_tools:
            build_host_tools(env, args.feature, args.verbose, args.jobs)
        build_dir = configure_target(env, args.arch, args.feature, dep_prefix,
                                     args.verbose, args.debuggable)
        binary = build_target(env, build_dir, args.arch, args.feature,
                              args.verbose, args.jobs)
        stage = repackage_payload(env, args.arch, args.feature, binary,
                                  args.verbose)
        archive_bundle(env, args.arch, args.feature, stage,
                       args.keep, args.no_archive)
        if args.install or args.run:
            install_and_run(env, stage, args.arch, args.feature,
                            args.serial, args.run)
    except BuildError as e:
        sys.stderr.write(f"[build] FAILED: {e}\n")
        return 1
    return 0

if __name__ == "__main__":
    sys.exit(main())
