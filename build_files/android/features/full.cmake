# build_files/android/features/full.cmake
#
# Everything ON: the editor + player + Cycles + EEVEE Next + OIDN + OpenVDB +
# USD + Alembic + MaterialX + Fluid sim + Motion tracking + Python with pip.
#
# The result is a ~240 MB APK when wrapped. Use this when you want the entire
# Blender editor inside Android AND the UPBGE game engine on top, e.g. for
# developing a game on-device before switching to `player-only` for release.

# Common Android toggles go first.
include("${CMAKE_CURRENT_LIST_DIR}/common.cmake")

# ---- Editor -------------------------------------------------------------------
set(WITH_BLENDER                 ON  CACHE BOOL "" FORCE)

# ---- Renderers ----------------------------------------------------------------
set(WITH_CYCLES                  ON  CACHE BOOL "" FORCE)
set(WITH_CYCLES_OSL              ON  CACHE BOOL "" FORCE)
set(WITH_CYCLES_EMBREE           ON  CACHE BOOL "" FORCE)
set(WITH_CYCLES_DEVICE_OPTIX     OFF CACHE BOOL "" FORCE)  # no Optix on Android
set(WITH_CYCLES_DEVICE_CUDA      OFF CACHE BOOL "" FORCE)  # no CUDA on Android
set(WITH_CYCLES_DEVICE_HIP       OFF CACHE BOOL "" FORCE)  # no HIP on Android
set(WITH_CYCLES_DEVICE_METAL     OFF CACHE BOOL "" FORCE)
set(WITH_CYCLES_DEBUG            OFF CACHE BOOL "" FORCE)
set(WITH_CYCLES_NATIVE_ONLY      OFF CACHE BOOL "" FORCE)

set(WITH_EEVEE_NEXT              ON  CACHE BOOL "" FORCE)
set(WITH_EEVEE                   ON  CACHE BOOL "" FORCE)

# ---- Denoising / post ---------------------------------------------------------
set(WITH_OPENIMAGEDENOISE        ON  CACHE BOOL "" FORCE)
set(WITH_DENOISE                 ON  CACHE BOOL "" FORCE)

# ---- VDB / USD / Alembic ------------------------------------------------------
set(WITH_OPENVDB                 ON  CACHE BOOL "" FORCE)
set(WITH_OPENVDB_BLOSC           OFF CACHE BOOL "" FORCE)  # blosc is unused on Android
set(WITH_USD                     ON  CACHE BOOL "" FORCE)
set(WITH_ALEMBIC                 ON  CACHE BOOL "" FORCE)
set(WITH_HDF5                    ON  CACHE BOOL "" FORCE)

# ---- IO -----------------------------------------------------------------------
set(WITH_OPENCOLLADA             OFF CACHE BOOL "" FORCE)  # heavy, not needed
set(WITH_ALEMBIC_HDF5            ON  CACHE BOOL "" FORCE)
set(WITH_OPENIMAGEIO             ON  CACHE BOOL "" FORCE)
set(WITH_IMAGE_OPENEXR           ON  CACHE BOOL "" FORCE)
set(WITH_IMAGE_DDS               ON  CACHE BOOL "" FORCE)
set(WITH_IMAGE_CINEON            ON  CACHE BOOL "" FORCE)
set(WITH_IMAGE_HDR               ON  CACHE BOOL "" FORCE)
set(WITH_IMAGE_TIFF              ON  CACHE BOOL "" FORCE)
set(WITH_IMAGE_WEBP              ON  CACHE BOOL "" FORCE)
set(WITH_IMAGE_OPENJPEG          ON  CACHE BOOL "" FORCE)

# ---- Simulation / geometry ----------------------------------------------------
set(WITH_FLUID                   ON  CACHE BOOL "" FORCE)
set(WITH_MANTA                   ON  CACHE BOOL "" FORCE)
set(WITH_MOD_FLUID               ON  CACHE BOOL "" FORCE)
set(WITH_MOD_OCEANSIM            ON  CACHE BOOL "" FORCE)
set(WITH_OPENSUBDIV              ON  CACHE BOOL "" FORCE)
set(WITH_OPENPGL                 ON  CACHE BOOL "" FORCE)
set(WITH_MANIFOLD                ON  CACHE BOOL "" FORCE)
set(WITH_DRACO                   ON  CACHE BOOL "" FORCE)

# ---- Threading ----------------------------------------------------------------
set(WITH_TBB                     ON  CACHE BOOL "" FORCE)

# ---- MaterialX / PBR ----------------------------------------------------------
set(WITH_MATERIALX               ON  CACHE BOOL "" FORCE)
set(WITH_HYDRA                   OFF CACHE BOOL "" FORCE)  # needs USD render delegate

# ---- Motion tracking / video --------------------------------------------------
set(WITH_LIBMV                   ON  CACHE BOOL "" FORCE)
set(WITH_LIBMV_SCHUR_SPECIALIZATIONS OFF CACHE BOOL "" FORCE)
set(WITH_POTRACE                 ON  CACHE BOOL "" FORCE)

# ---- Other --------------------------------------------------------------------
set(WITH_BULLET                  ON  CACHE BOOL "" FORCE)
set(WITH_OPENMP                  OFF CACHE BOOL "" FORCE)  # OpenMP not in NDK
set(WITH_PCRE                    ON  CACHE BOOL "" FORCE)
set(WITH_XR_OPENXR               OFF CACHE BOOL "" FORCE)  # no OpenXR on Android
set(WITH_GMP                     ON  CACHE BOOL "" FORCE)
set(WITH_JACK                    OFF CACHE BOOL "" FORCE)
set(WITH_PULSEAUDIO              OFF CACHE BOOL "" FORCE)
set(WITH_PIPEWIRE                OFF CACHE BOOL "" FORCE)
