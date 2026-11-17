# build_files/android/toolchain/android.toolchain.cmake
#
# CMake toolchain for cross-compiling UPBGE (and its dependency prefix) to
# Android. Works for both arm64-v8a and armeabi-v7a, picks the right NDK clang
# target, and restricts find_* to the dependency prefix so system libraries on
# the host are never picked up by accident.
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
#   ANDROID_ABI           (required)  arm64-v8a | armeabi-v7a | x86 | x86_64
#   ANDROID_PLATFORM      android-<N> (default android-31, i.e. Android 12)
#   ANDROID_NDK           NDK root
#   ANDROID_LIBDIR        DEPRECATED alias for CMAKE_FIND_ROOT_PATH
#   CMAKE_FIND_ROOT_PATH  where to look for headers/libs (deps prefix)

# --- Guard against re-inclusion ------------------------------------------------
if(DEFINED _UPBGE_ANDROID_TOOLCHAIN_LOADED)
    return()
endif()
set(_UPBGE_ANDROID_TOOLCHAIN_LOADED TRUE)

# --- ABI validation ------------------------------------------------------------
if(NOT DEFINED ANDROID_ABI)
    message(FATAL_ERROR "ANDROID_ABI is required (arm64-v8a, armeabi-v7a, x86, x86_64)")
endif()

set(_ABI_TRIPLET "")
set(_ABI_LIB_SUBDIR "")
if(ANDROID_ABI STREQUAL "arm64-v8a")
    set(_ABI_TRIPLET "aarch64-linux-android")
    set(_ABI_LIB_SUBDIR "aarch64-linux-android")
elseif(ANDROID_ABI STREQUAL "armeabi-v7a")
    set(_ABI_TRIPLET "arm-linux-androideabi")
    set(_ABI_LIB_SUBDIR "arm-linux-androideabi")
elseif(ANDROID_ABI STREQUAL "x86_64")
    set(_ABI_TRIPLET "x86_64-linux-android")
    set(_ABI_LIB_SUBDIR "x86_64-linux-android")
elseif(ANDROID_ABI STREQUAL "x86")
    set(_ABI_TRIPLET "i686-linux-android")
    set(_ABI_LIB_SUBDIR "i686-linux-android")
else()
    message(FATAL_ERROR "unsupported ANDROID_ABI: ${ANDROID_ABI}")
endif()

# --- NDK discovery -------------------------------------------------------------
if(NOT DEFINED ANDROID_NDK)
    if(DEFINED ENV{ANDROID_NDK_HOME})
        set(ANDROID_NDK "$ENV{ANDROID_NDK_HOME}")
    elseif(DEFINED ENV{ANDROID_NDK_ROOT})
        set(ANDROID_NDK "$ENV{ANDROID_NDK_ROOT}")
    else()
        message(FATAL_ERROR "ANDROID_NDK not set and no ANDROID_NDK_HOME env var")
    endif()
endif()
if(NOT IS_DIRECTORY "${ANDROID_NDK}")
    message(FATAL_ERROR "ANDROID_NDK is not a directory: ${ANDROID_NDK}")
endif()

if(NOT DEFINED ANDROID_PLATFORM)
    set(ANDROID_PLATFORM "android-31")
endif()

# --- Platform name (for NDK unified headers) -----------------------------------
string(REGEX REPLACE "^android-" "" _API_LEVEL "${ANDROID_PLATFORM}")
if(NOT _API_LEVEL MATCHES "^[0-9]+$")
    message(FATAL_ERROR "ANDROID_PLATFORM must be android-<number>, got: ${ANDROID_PLATFORM}")
endif()

# --- Compilers -----------------------------------------------------------------
set(NDK_HOST_TAG "linux-x86_64")
if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")
    if(CMAKE_HOST_SYSTEM_PROCESSOR STREQUAL "arm64")
        set(NDK_HOST_TAG "darwin-x86_64")  # NDK ships x86_64 binaries, run via Rosetta
    else()
        set(NDK_HOST_TAG "darwin-x86_64")
    endif()
elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")
    set(NDK_HOST_TAG "windows-x86_64")
endif()

set(NDK_TOOLCHAIN_ROOT "${ANDROID_NDK}/toolchains/llvm/prebuilt/${NDK_HOST_TAG}")
if(NOT IS_DIRECTORY "${NDK_TOOLCHAIN_ROOT}")
    message(FATAL_ERROR "NDK toolchain dir not found: ${NDK_TOOLCHAIN_ROOT}")
endif()

# Use the NDK's clang wrappers with the target triple baked in.
# api suffix is appended: aarch64-linux-android31-clang
set(CMAKE_C_COMPILER   "${NDK_TOOLCHAIN_ROOT}/bin/${_ABI_TRIPLET}${_API_LEVEL}-clang")
set(CMAKE_CXX_COMPILER "${NDK_TOOLCHAIN_ROOT}/bin/${_ABI_TRIPLET}${_API_LEVEL}-clang++")
set(CMAKE_AR           "${NDK_TOOLCHAIN_ROOT}/bin/llvm-ar" CACHE FILEPATH "")
set(CMAKE_RANLIB       "${NDK_TOOLCHAIN_ROOT}/bin/llvm-ranlib" CACHE FILEPATH "")
set(CMAKE_STRIP        "${NDK_TOOLCHAIN_ROOT}/bin/llvm-strip" CACHE FILEPATH "")
set(CMAKE_LINKER       "${NDK_TOOLCHAIN_ROOT}/bin/ld.lld" CACHE FILEPATH "")

# --- sysroot (NDK unified headers) ---------------------------------------------
set(CMAKE_SYSROOT "${NDK_TOOLCHAIN_ROOT}/sysroot")
set(ANDROID_SYSROOT "${CMAKE_SYSROOT}")

# --- Compile / link flags ------------------------------------------------------
# Position-independent code is required for Android shared objects.
set(ANDROID_PIE TRUE)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# C++17 minimum (matches UPBGE master); RTTI is enabled because Blender uses it
# in several modules; exceptions are ON because Python throws C++ exceptions.
set(_COMMON_FLAGS
    "-D__ANDROID_API__=${_API_LEVEL}"
    "-fPIC"
    "-fstack-protector-strong"
    "-funwind-tables"
    "-fno-strict-aliasing"
    "-ffunction-sections"
    "-fdata-sections"
    "-fvisibility=hidden"
    "-fvisibility-inlines-hidden"
)
set(_COMMON_LINK_FLAGS
    "-Wl,--gc-sections"
    "-Wl,--build-id=sha1"
    "-Wl,-z,noexecstack"
    "-Wl,-z,relro"
    "-Wl,-z,now"
    "-Wl,--exclude-libs,ALL"
)

string(JOIN " " CMAKE_C_FLAGS_INIT ${_COMMON_FLAGS})
string(JOIN " " CMAKE_CXX_FLAGS_INIT ${_COMMON_FLAGS}
    "-fexceptions"
    "-frtti"
    "-std=c++17")
string(JOIN " " CMAKE_EXE_LINKER_FLAGS_INIT ${_COMMON_LINK_FLAGS})
string(JOIN " " CMAKE_SHARED_LINKER_FLAGS_INIT ${_COMMON_LINK_FLAGS})
string(JOIN " " CMAKE_MODULE_LINKER_FLAGS_INIT ${_COMMON_LINK_FLAGS})

# --- find_* restriction --------------------------------------------------------
# Only look under the sysroot and the deps prefix; never in /usr or /usr/local.
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# Make sure that the deps prefix, when given via -DCMAKE_FIND_ROOT_PATH, is
# searched BEFORE the sysroot, so vendored static libs win over NDK stubs.
if(DEFINED ANDROID_LIBDIR AND NOT DEFINED CMAKE_FIND_ROOT_PATH)
    set(CMAKE_FIND_ROOT_PATH "${ANDROID_LIBDIR}")
endif()
if(NOT CMAKE_FIND_ROOT_PATH)
    set(CMAKE_FIND_ROOT_PATH "${CMAKE_SYSROOT}")
endif()

# Prefer static libs over shared: every dep ships as a .a that gets linked
# into the single libblender.so / blenderplayer binary.
set(CMAKE_FIND_LIBRARY_SUFFIXES ".a" ".so")

# --- Don't try to run target binaries on the host ------------------------------
set(CMAKE_CROSSCOMPILING TRUE)
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)

# --- Stubs that 3rd-party CMakeLists sometimes look for ------------------------
set(ANDROID TRUE)
set(ANDROID_NDK_VERSION "$ENV{ANDROID_NDK_VERSION}")
set(ANDROID_ABI "${ANDROID_ABI}")
set(ANDROID_PLATFORM "${ANDROID_PLATFORM}")

# Expose for downstream CMakeLists.
set(UPBGE_ANDROID TRUE)
set(UPBGE_ANDROID_ABI "${ANDROID_ABI}")
set(UPBGE_ANDROID_NDK "${ANDROID_NDK}")
set(UPBGE_ANDROID_API "${_API_LEVEL}")
message(STATUS "[upbge-android] ABI=${ANDROID_ABI} API=${_API_LEVEL} "
               "NDK=${ANDROID_NDK} ROOT=${CMAKE_FIND_ROOT_PATH}")
