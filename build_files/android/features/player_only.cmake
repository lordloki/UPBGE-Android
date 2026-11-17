# build_files/android/features/player_only.cmake
#
# The smallest configuration that produces a working UPBGE `blenderplayer`
# capable of loading a .blend and rendering it with EEVEE / the game engine.
#
# Drops:
#   - the Blender editor (WITH_BLENDER=OFF)
#   - Cycles (no offline path tracing on a phone)
#   - OIDN / OpenVDB / USD / Alembic / MaterialX (heavy IO not needed by a game)
#   - fluid sim / motion tracking (offline-only tools)
#   - TBB (single-threaded fallback is fine for games)
#
# Result: ~30-50 MB binary + ~20-30 MB Python + ~5 MB assets = ~80 MB APK
# once wrapped by the future add-on.

# Common Android toggles first.
include("${CMAKE_CURRENT_LIST_DIR}/common.cmake")

# ---- Editor OFF: only the player is built ------------------------------------
set(WITH_BLENDER                 OFF CACHE BOOL "" FORCE)
set(WITH_PLAYER                  ON  CACHE BOOL "" FORCE)
set(WITH_GAMEENGINE              ON  CACHE BOOL "" FORCE)

# ---- Renderer: EEVEE only, Vulkan-backed -------------------------------------
set(WITH_EEVEE_NEXT              ON  CACHE BOOL "" FORCE)
set(WITH_EEVEE                   ON  CACHE BOOL "" FORCE)
set(WITH_CYCLES                  OFF CACHE BOOL "" FORCE)
set(WITH_CYCLES_OSL              OFF CACHE BOOL "" FORCE)
set(WITH_CYCLES_EMBREE           OFF CACHE BOOL "" FORCE)
set(WITH_CYCLES_DEBUG            OFF CACHE BOOL "" FORCE)

# ---- Denoising OFF ------------------------------------------------------------
set(WITH_OPENIMAGEDENOISE        OFF CACHE BOOL "" FORCE)
set(WITH_DENOISE                 OFF CACHE BOOL "" FORCE)

# ---- Heavy IO OFF -------------------------------------------------------------
set(WITH_OPENVDB                 OFF CACHE BOOL "" FORCE)
set(WITH_USD                     OFF CACHE BOOL "" FORCE)
set(WITH_ALEMBIC                 OFF CACHE BOOL "" FORCE)
set(WITH_HDF5                    OFF CACHE BOOL "" FORCE)
set(WITH_MATERIALX               OFF CACHE BOOL "" FORCE)
set(WITH_HYDRA                   OFF CACHE BOOL "" FORCE)

# ---- Image formats minimal ----------------------------------------------------
set(WITH_IMAGE_OPENEXR           OFF CACHE BOOL "" FORCE)
set(WITH_IMAGE_DDS               ON  CACHE BOOL "" FORCE)
set(WITH_IMAGE_HDR               ON  CACHE BOOL "" FORCE)
set(WITH_IMAGE_TIFF              ON  CACHE BOOL "" FORCE)
set(WITH_IMAGE_WEBP              ON  CACHE BOOL "" FORCE)
set(WITH_IMAGE_OPENJPEG          OFF CACHE BOOL "" FORCE)
set(WITH_IMAGE_CINEON            OFF CACHE BOOL "" FORCE)
set(WITH_OPENIMAGEIO             OFF CACHE BOOL "" FORCE)

# ---- Simulation OFF (offline-only) -------------------------------------------
set(WITH_FLUID                   OFF CACHE BOOL "" FORCE)
set(WITH_MANTA                   OFF CACHE BOOL "" FORCE)
set(WITH_MOD_FLUID               OFF CACHE BOOL "" FORCE)
set(WITH_MOD_OCEANSIM            OFF CACHE BOOL "" FORCE)
set(WITH_OPENSUBDIV              OFF CACHE BOOL "" FORCE)
set(WITH_OPENPGL                 OFF CACHE BOOL "" FORCE)
set(WITH_MANIFOLD                OFF CACHE BOOL "" FORCE)
set(WITH_DRACO                   OFF CACHE BOOL "" FORCE)

# ---- Motion tracking OFF ------------------------------------------------------
set(WITH_LIBMV                   OFF CACHE BOOL "" FORCE)
set(WITH_POTRACE                 OFF CACHE BOOL "" FORCE)

# ---- Threading: drop TBB (use std::thread fallback) --------------------------
set(WITH_TBB                     OFF CACHE BOOL "" FORCE)
set(WITH_OPENMP                  OFF CACHE BOOL "" FORCE)

# ---- Audio: keep FFmpeg + OpenAL + SDL2 (a game needs sound) -----------------
set(WITH_FFMPEG                  ON  CACHE BOOL "" FORCE)
set(WITH_CODEC_FFMPEG            ON  CACHE BOOL "" FORCE)
set(WITH_AUDASPACE               ON  CACHE BOOL "" FORCE)
set(WITH_AUDASPACE_OPENAL        ON  CACHE BOOL "" FORCE)
set(WITH_OPENAL                  ON  CACHE BOOL "" FORCE)
set(WITH_SDL                     OFF CACHE BOOL "" FORCE)  # SDL optional; OpenAL enough

# ---- Physics: Bullet stays ON (game engine) ----------------------------------
set(WITH_BULLET                  ON  CACHE BOOL "" FORCE)

# ---- Math ---------------------------------------------------------------------
set(WITH_GMP                     OFF CACHE BOOL "" FORCE)
set(WITH_PCRE                    OFF CACHE BOOL "" FORCE)

# ---- Misc ---------------------------------------------------------------------
set(WITH_XR_OPENXR               OFF CACHE BOOL "" FORCE)
set(WITH_JACK                    OFF CACHE BOOL "" FORCE)
set(WITH_PULSEAUDIO              OFF CACHE BOOL "" FORCE)
set(WITH_PIPEWIRE                OFF CACHE BOOL "" FORCE)
set(WITH_OPENCOLLADA             OFF CACHE BOOL "" FORCE)
