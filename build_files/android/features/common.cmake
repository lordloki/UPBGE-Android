# build_files/android/features/common.cmake
#
# Options shared by every Android configuration (CMake initial cache, `-C`).
# Only real UPBGE options: CMake silently accepts unknown cache entries, so a
# misspelled option is a feature left at its desktop default.
#
# The same file configures the host code generators (makesdna, makesrna, ...):
# their output depends on these options, so host and target must agree.

# ---- Windowing / GPU ----------------------------------------------------------
# GHOST is built headless; the player adds its own Android backend
# (source/gameengine/GamePlayer/android). Vulkan only: no desktop GL on Android.
set(WITH_HEADLESS                 ON  CACHE BOOL "" FORCE)
set(WITH_GHOST_X11                OFF CACHE BOOL "" FORCE)
set(WITH_GHOST_WAYLAND            OFF CACHE BOOL "" FORCE)
set(WITH_GHOST_SDL                OFF CACHE BOOL "" FORCE)
set(WITH_GHOST_XDND               OFF CACHE BOOL "" FORCE)
set(WITH_X11_XINPUT               OFF CACHE BOOL "" FORCE)
set(WITH_X11_XINERAMA             OFF CACHE BOOL "" FORCE)
set(WITH_X11_XF86VMODE            OFF CACHE BOOL "" FORCE)
set(WITH_X11_XFIXES               OFF CACHE BOOL "" FORCE)
set(WITH_INPUT_IME                OFF CACHE BOOL "" FORCE)
set(WITH_INPUT_NDOF               OFF CACHE BOOL "" FORCE)
set(WITH_XR_OPENXR                OFF CACHE BOOL "" FORCE)
set(WITH_VULKAN_BACKEND           ON  CACHE BOOL "" FORCE)
set(WITH_OPENGL_BACKEND           OFF CACHE BOOL "" FORCE)
set(WITH_RENDERDOC                OFF CACHE BOOL "" FORCE)

# ---- Game engine --------------------------------------------------------------
set(WITH_BLENDER                  OFF CACHE BOOL "" FORCE)
set(WITH_GAMEENGINE               ON  CACHE BOOL "" FORCE)
set(WITH_PLAYER                   ON  CACHE BOOL "" FORCE)
set(WITH_BULLET                   ON  CACHE BOOL "" FORCE)
set(WITH_GAMEENGINE_DECKLINK      OFF CACHE BOOL "" FORCE)

# ---- Python (static interpreter inside the player .so) ------------------------
set(WITH_PYTHON                   ON  CACHE BOOL "" FORCE)
set(WITH_PYTHON_MODULE            OFF CACHE BOOL "" FORCE)
set(WITH_PYTHON_SAFETY            OFF CACHE BOOL "" FORCE)
set(WITH_PYTHON_NUMPY             OFF CACHE BOOL "" FORCE)
# The APK is assembled by scripts/package_player.sh, not by `make install`.
set(WITH_PYTHON_INSTALL           OFF CACHE BOOL "" FORCE)
set(WITH_PYTHON_INSTALL_NUMPY     OFF CACHE BOOL "" FORCE)
set(WITH_PYTHON_INSTALL_REQUESTS  OFF CACHE BOOL "" FORCE)
set(WITH_PYTHON_INSTALL_ZSTANDARD OFF CACHE BOOL "" FORCE)

# ---- Audio --------------------------------------------------------------------
set(WITH_AUDASPACE                ON  CACHE BOOL "" FORCE)
set(WITH_OPENAL                   ON  CACHE BOOL "" FORCE)
set(WITH_CODEC_FFMPEG             ON  CACHE BOOL "" FORCE)
set(WITH_CODEC_SNDFILE            ON  CACHE BOOL "" FORCE)
set(WITH_SDL_AUDIO                OFF CACHE BOOL "" FORCE)
set(WITH_JACK                     OFF CACHE BOOL "" FORCE)
set(WITH_PULSEAUDIO               OFF CACHE BOOL "" FORCE)
set(WITH_PIPEWIRE                 OFF CACHE BOOL "" FORCE)
set(WITH_COREAUDIO                OFF CACHE BOOL "" FORCE)
set(WITH_RUBBERBAND               OFF CACHE BOOL "" FORCE)

# ---- Build --------------------------------------------------------------------
# Strict: a feature whose library is missing fails the configure instead of being
# switched off quietly on one side only. Host and target then provably build the
# same feature set. Build-environment options (LIBDIR, linker, portable install)
# are passed by build.py to the target configure only.
set(WITH_STRICT_BUILD_OPTIONS     ON  CACHE BOOL "" FORCE)
set(WITH_INTERNATIONAL            OFF CACHE BOOL "" FORCE)
set(WITH_BUILDINFO                OFF CACHE BOOL "" FORCE)
set(WITH_BLENDER_THUMBNAILER      OFF CACHE BOOL "" FORCE)
set(WITH_DOC_MANPAGE              OFF CACHE BOOL "" FORCE)
set(WITH_GTESTS                   OFF CACHE BOOL "" FORCE)
set(WITH_TRACY                    OFF CACHE BOOL "" FORCE)
