# build_files/android/features/common.cmake
#
# Feature toggles shared by every Android configuration of UPBGE.
# These are -D options passed to CMake BEFORE the per-feature file (-C flag).
# Anything here is applied on top of UPBGE's own defaults.

# ---- Android platform ---------------------------------------------------------
set(WITH_ANDROID                   ON  CACHE BOOL "" FORCE)
set(WITH_ANDROID_DEPLOYMENT        ON  CACHE BOOL "" FORCE)

# Use Vulkan; there is no GLX/EGL/WGL on Android.
set(WITH_GPU_VULKAN                ON  CACHE BOOL "" FORCE)
set(WITH_GPU_OPENGL                OFF CACHE BOOL "" FORCE)
set(VULKAN_SDK                     ""  CACHE PATH "" FORCE)
set(WITH_VULKAN_GUARDED_ALLOC      OFF CACHE BOOL "" FORCE)

# No X11 / Wayland / Cocoa / Win32.
set(WITH_GHOST_X11                 OFF CACHE BOOL "" FORCE)
set(WITH_GHOST_WAYLAND             OFF CACHE BOOL "" FORCE)
set(WITH_GHOST_COCOA               OFF CACHE BOOL "" FORCE)
set(WITH_GHOST_WIN32               OFF CACHE BOOL "" FORCE)
set(WITH_GHOST_SDL                 OFF CACHE BOOL "" FORCE)
set(WITH_GHOST_ANDROID             ON  CACHE BOOL "" FORCE)

# Audio via OpenSL ES (built into NDK) or OpenAL.
set(WITH_AUDASPACE                 ON  CACHE BOOL "" FORCE)
set(WITH_AUDASPACE_OPENAL          ON  CACHE BOOL "" FORCE)
set(WITH_OPENAL                    ON  CACHE BOOL "" FORCE)
set(WITH_SDL                       ON  CACHE BOOL "" FORCE)
set(SDL2_LIBRARY                   ""  CACHE FILEPATH "" FORCE)
set(SDL2_INCLUDE_DIR               ""  CACHE PATH "" FORCE)

# FFmpeg is required to load most game audio/video assets.
set(WITH_FFMPEG                    ON  CACHE BOOL "" FORCE)
set(WITH_CODEC_FFMPEG              ON  CACHE BOOL "" FORCE)

# Standalone Python interpreter, no module install under site-packages.
set(WITH_PYTHON                    ON  CACHE BOOL "" FORCE)
set(WITH_PYTHON_INSTALL            ON  CACHE BOOL "" FORCE)
set(WITH_PYTHON_SAFETY             OFF CACHE BOOL "" FORCE)
set(WITH_PYTHON_MODULE_INSTALL     OFF CACHE BOOL "" FORCE)

# Crash handlers and Windows-only stuff: disabled everywhere.
set(WITH_CRASHPAD                  OFF CACHE BOOL "" FORCE)
set(WITH_BREAKPAD                  OFF CACHE BOOL "" FORCE)
set(WITH_EXTERNAL_CRASHPAD         OFF CACHE BOOL "" FORCE)
set(WITH_WINDOWS_BUNDLE            OFF CACHE BOOL "" FORCE)

# Tests and docs never belong in a player bundle.
set(WITH_GTESTS                    OFF CACHE BOOL "" FORCE)
set(WITH_INTERNATIONAL             OFF CACHE BOOL "" FORCE)  # i18n is host-only
set(WITH_INSTALL_PORTABLE          ON  CACHE BOOL "" FORCE)
set(WITH_STANDALONE_BUILD          ON  CACHE BOOL "" FORCE)

# UPBGE game engine itself — always on.
set(WITH_GAMEENGINE                ON  CACHE BOOL "" FORCE)
set(WITH_PLAYER                    ON  CACHE BOOL "" FORCE)
set(WITH_BULLET                    ON  CACHE BOOL "" FORCE)
set(WITH_PLAYER_RAS_OPENGLES2      OFF CACHE BOOL "" FORCE)  # UPBGE legacy flag

# Disable AVX / SIMD paths that do not exist on ARM.
set(CMAKE_C_FLAGS_INIT             ""  CACHE STRING "" FORCE)
set(CMAKE_CXX_FLAGS_INIT           ""  CACHE STRING "" FORCE)
