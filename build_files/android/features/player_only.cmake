# build_files/android/features/player_only.cmake
#
# The smallest configuration that produces a working UPBGE player: loads a
# .blend and renders it with EEVEE / the game engine over Vulkan.
#
# Everything below is either offline-only (simulation bakes, path tracing,
# importers) or a dependency the Android deps prefix does not build.

include("${CMAKE_CURRENT_LIST_DIR}/common.cmake")

# ---- Renderers / GPU compute ----------------------------------------------------
set(WITH_CYCLES                   OFF CACHE BOOL "" FORCE)
set(WITH_CYCLES_OSL               OFF CACHE BOOL "" FORCE)
set(WITH_CYCLES_EMBREE            OFF CACHE BOOL "" FORCE)
set(WITH_CYCLES_PATH_GUIDING      OFF CACHE BOOL "" FORCE)
set(WITH_CYCLES_DEVICE_CUDA       OFF CACHE BOOL "" FORCE)
set(WITH_CYCLES_DEVICE_OPTIX      OFF CACHE BOOL "" FORCE)
set(WITH_CYCLES_DEVICE_HIP        OFF CACHE BOOL "" FORCE)
set(WITH_CYCLES_DEVICE_HIPRT      OFF CACHE BOOL "" FORCE)
set(WITH_CYCLES_DEVICE_ONEAPI     OFF CACHE BOOL "" FORCE)
set(WITH_EMBREE                   OFF CACHE BOOL "" FORCE)
set(WITH_OPENIMAGEDENOISE         OFF CACHE BOOL "" FORCE)
set(WITH_DLSS                     OFF CACHE BOOL "" FORCE)
set(WITH_LLVM                     OFF CACHE BOOL "" FORCE)
set(WITH_FREESTYLE                OFF CACHE BOOL "" FORCE)

# ---- Heavy IO -------------------------------------------------------------------
set(WITH_OPENVDB                  OFF CACHE BOOL "" FORCE)
set(WITH_NANOVDB                  OFF CACHE BOOL "" FORCE)
set(WITH_USD                      OFF CACHE BOOL "" FORCE)
set(WITH_ALEMBIC                  OFF CACHE BOOL "" FORCE)
set(WITH_MATERIALX                OFF CACHE BOOL "" FORCE)
set(WITH_HYDRA                    OFF CACHE BOOL "" FORCE)
set(WITH_OPENTIMELINEIO           OFF CACHE BOOL "" FORCE)
set(WITH_IO_FBX                   OFF CACHE BOOL "" FORCE)
set(WITH_IO_SPZ                   OFF CACHE BOOL "" FORCE)
set(WITH_DRACO                    OFF CACHE BOOL "" FORCE)
set(WITH_MESHOPTIMIZER            OFF CACHE BOOL "" FORCE)
set(WITH_KTX                      OFF CACHE BOOL "" FORCE)
set(WITH_HARU                     OFF CACHE BOOL "" FORCE)
set(WITH_PUGIXML                  OFF CACHE BOOL "" FORCE)

# ---- Image formats --------------------------------------------------------------
set(WITH_IMAGE_OPENJPEG           OFF CACHE BOOL "" FORCE)
set(WITH_IMAGE_CINEON             OFF CACHE BOOL "" FORCE)
set(WITH_IMAGE_WEBP               ON  CACHE BOOL "" FORCE)

# ---- Offline tools / simulation -------------------------------------------------
set(WITH_MOD_FLUID                OFF CACHE BOOL "" FORCE)
set(WITH_MOD_OCEANSIM             OFF CACHE BOOL "" FORCE)
set(WITH_MOD_REMESH               OFF CACHE BOOL "" FORCE)
set(WITH_QUADRIFLOW               OFF CACHE BOOL "" FORCE)
set(WITH_OPENSUBDIV               OFF CACHE BOOL "" FORCE)
set(WITH_MANIFOLD                 OFF CACHE BOOL "" FORCE)
set(WITH_POTRACE                  OFF CACHE BOOL "" FORCE)
set(WITH_LIBMV                    OFF CACHE BOOL "" FORCE)
set(WITH_UV_SLIM                  OFF CACHE BOOL "" FORCE)
set(WITH_GMP                      OFF CACHE BOOL "" FORCE)
set(WITH_JOLT                     OFF CACHE BOOL "" FORCE)

# ---- Threading ------------------------------------------------------------------
# Static oneTBB (deps/recipes/tbb.sh): parallel ranges and task pools.
set(WITH_TBB                      ON  CACHE BOOL "" FORCE)
set(WITH_TBB_MALLOC_PROXY         OFF CACHE BOOL "" FORCE)
