# build_files/android/toolchain/android.toolchain.cmake
#
# CMake toolchain for cross-compiling UPBGE (and its dependency prefix) to
# Android arm64-v8a.
#
# This is a thin wrapper around the NDK's own toolchain file. Only the NDK file
# sets CMAKE_SYSTEM_NAME=Android, CMAKE_SYSTEM_PROCESSOR=aarch64, the API-level
# library directories (liblog, libandroid, libOpenSLES, libvulkan) and the
# libc++ runtime consistently. Without them CMake believes it is building for
# the host (x86_64 Linux): SIMD code paths are selected for the wrong CPU,
# GNUInstallDirs installs into lib64 on openSUSE/Fedora, try_run() executes
# ARM binaries on the host and check_function_exists() tests nothing.
#
# Usage from build.py / deps/build.sh:
#   cmake -DCMAKE_TOOLCHAIN_FILE=<this> \
#         -DANDROID_ABI=arm64-v8a \
#         -DANDROID_PLATFORM=android-31 \
#         -DANDROID_NDK=<ndk-home> \
#         -DCMAKE_FIND_ROOT_PATH=<deps-prefix> \
#         ...
#
# Variables you can override:
#   ANDROID_ABI           arm64-v8a (default; the only supported ABI)
#   ANDROID_PLATFORM      android-<N> (default android-31, i.e. Android 12)
#   ANDROID_NDK           NDK root (default: $ANDROID_NDK_HOME / $ANDROID_NDK_ROOT)
#   ANDROID_STL           c++_static (default)
#   ANDROID_LIBDIR        DEPRECATED alias for CMAKE_FIND_ROOT_PATH
#   CMAKE_FIND_ROOT_PATH  where to look for headers/libs (deps prefix)

# CMake reads the toolchain several times during the first configure; appending
# flags more than once would make the first build and later rebuilds disagree.
if(DEFINED _UPBGE_ANDROID_TOOLCHAIN_LOADED)
  return()
endif()
set(_UPBGE_ANDROID_TOOLCHAIN_LOADED TRUE)

# --- Inputs ------------------------------------------------------------------
# Defaults matter: try_compile() re-reads this file in a fresh project that
# only sees the variables listed in CMAKE_TRY_COMPILE_PLATFORM_VARIABLES.
if(NOT ANDROID_ABI)
  set(ANDROID_ABI "arm64-v8a")
endif()
if(NOT ANDROID_ABI STREQUAL "arm64-v8a")
  message(FATAL_ERROR "unsupported ANDROID_ABI: ${ANDROID_ABI} (only arm64-v8a)")
endif()

if(NOT ANDROID_PLATFORM)
  set(ANDROID_PLATFORM "android-31")
endif()
if(NOT ANDROID_PLATFORM MATCHES "^android-[0-9]+$")
  message(FATAL_ERROR "ANDROID_PLATFORM must be android-<number>, got: ${ANDROID_PLATFORM}")
endif()

if(NOT ANDROID_NDK)
  if(DEFINED ENV{ANDROID_NDK_HOME})
    set(ANDROID_NDK "$ENV{ANDROID_NDK_HOME}")
  elseif(DEFINED ENV{ANDROID_NDK_ROOT})
    set(ANDROID_NDK "$ENV{ANDROID_NDK_ROOT}")
  else()
    message(FATAL_ERROR "ANDROID_NDK not set and no ANDROID_NDK_HOME env var")
  endif()
endif()
if(NOT EXISTS "${ANDROID_NDK}/build/cmake/android.toolchain.cmake")
  message(FATAL_ERROR "not an Android NDK (no build/cmake/android.toolchain.cmake): ${ANDROID_NDK}")
endif()

# One C++ runtime, linked statically into the single player .so. A shared
# libc++ would have to be packaged and would cost a PLT hop per call.
if(NOT ANDROID_STL)
  set(ANDROID_STL "c++_static")
endif()

# Pin the NDK's legacy toolchain flow (also the NDK r23b+ default): it merges
# CMAKE_<LANG>_FLAGS deterministically, which the flag appends below rely on.
if(NOT DEFINED ANDROID_USE_LEGACY_TOOLCHAIN_FILE)
  set(ANDROID_USE_LEGACY_TOOLCHAIN_FILE ON)
endif()

if(DEFINED ANDROID_LIBDIR AND NOT CMAKE_FIND_ROOT_PATH)
  set(CMAKE_FIND_ROOT_PATH "${ANDROID_LIBDIR}")
endif()

include("${ANDROID_NDK}/build/cmake/android.toolchain.cmake")

# The NDK file overwrites this list; append afterwards so try_compile() can
# locate the NDK through this wrapper.
list(APPEND CMAKE_TRY_COMPILE_PLATFORM_VARIABLES ANDROID_NDK ANDROID_USE_LEGACY_TOOLCHAIN_FILE)

# --- Code generation ---------------------------------------------------------
# Every dependency is a static archive linked into one shared object: PIC is
# mandatory. Hidden visibility keeps the dynamic symbol table small, which
# shortens load time and lets the linker bind calls directly instead of
# through the GOT. Exceptions, RTTI, unwind tables, stack protector, section
# GC, relro/now and noexecstack are already added by the NDK toolchain.
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
string(APPEND CMAKE_C_FLAGS " -fvisibility=hidden")
string(APPEND CMAKE_CXX_FLAGS " -fvisibility=hidden -fvisibility-inlines-hidden")

# --- find_* restriction --------------------------------------------------------
# Search only the deps prefix and the NDK sysroot; never the host /usr.
# Programs (python3, git, ...) still come from the host.
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# Note: CMAKE_FIND_LIBRARY_SUFFIXES cannot be set here (CMakeGenericSystem
# resets it to ".so;.a" after the toolchain). Static linking is guaranteed by
# keeping shared objects out of the deps prefix instead; see deps/build.sh.

# Expose for downstream CMakeLists.
set(UPBGE_ANDROID TRUE)
set(UPBGE_ANDROID_ABI "${ANDROID_ABI}")
set(UPBGE_ANDROID_NDK "${ANDROID_NDK}")
string(REGEX REPLACE "^android-" "" UPBGE_ANDROID_API "${ANDROID_PLATFORM}")
message(STATUS "[upbge-android] ABI=${ANDROID_ABI} API=${UPBGE_ANDROID_API} "
               "NDK=${ANDROID_NDK} ROOT=${CMAKE_FIND_ROOT_PATH}")
