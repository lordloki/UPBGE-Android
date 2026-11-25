# build_files/android/cmake/upbge_android_project.cmake
#
# Injected into the target configure as
#   -DCMAKE_PROJECT_Blender_INCLUDE=<this file>
# so it runs right after `project(Blender)`. It adapts the cross build without
# editing Blender's CMake files.
#
# Inputs:
#   UPBGE_ANDROID_HOST_TOOLS_DIR  bin/ of a host build of the same UPBGE source,
#                                 configured with the same feature cache.
#   UPBGE_ANDROID_DEPS_PREFIX     the deps prefix (deps/build.sh output).

include_guard(GLOBAL)

if(NOT ANDROID)
  message(FATAL_ERROR "upbge_android_project.cmake is only for the Android toolchain")
endif()
if(NOT IS_DIRECTORY "${UPBGE_ANDROID_DEPS_PREFIX}/lib")
  message(FATAL_ERROR
    "UPBGE_ANDROID_DEPS_PREFIX is not a deps prefix: '${UPBGE_ANDROID_DEPS_PREFIX}'")
endif()

# --- pkg-config -----------------------------------------------------------------
# Set here rather than by the caller: ninja re-runs CMake without build.py's
# environment, and a host .pc (vulkan, shaderc) would then leak into the target.
set(ENV{PKG_CONFIG_LIBDIR}
  "${UPBGE_ANDROID_DEPS_PREFIX}/lib/pkgconfig:${UPBGE_ANDROID_DEPS_PREFIX}/share/pkgconfig")
set(ENV{PKG_CONFIG_PATH} "")

# --- Feature probes -------------------------------------------------------------
# bionic ships <execinfo.h> but declares backtrace() only from API 33, so with
# minSdk 31 the header probe in have_features.cmake passes and blenlib's
# system.cc fails to compile. Pre-seeding the result makes the probe a no-op.
set(HAVE_EXECINFO_H 0 CACHE INTERNAL "")

# --- Host code generators -------------------------------------------------------
# makesdna, makesrna, datatoc and shader_tool run during the build, so the
# cross-compiled ARM binaries are useless on the host. Each target still builds
# (Blender's CMake attaches sources and link flags to it), then its output is
# replaced by the host binary; every custom command references the tool through
# $<TARGET_FILE:...>, so it runs the host one. Their output only depends on the
# feature options and on LP64 little-endian layout, which x86_64/aarch64 share.
if(NOT IS_DIRECTORY "${UPBGE_ANDROID_HOST_TOOLS_DIR}")
  message(FATAL_ERROR
    "UPBGE_ANDROID_HOST_TOOLS_DIR is not a directory: '${UPBGE_ANDROID_HOST_TOOLS_DIR}'")
endif()

set(UPBGE_ANDROID_HOST_TOOLS makesdna makesrna datatoc shader_tool msgfmt)

# The host tools run against the host tree's precompiled libraries (its LIBDIR,
# unset for HOST_LIBDIR=system). Each target output becomes a wrapper script
# that sets LD_LIBRARY_PATH (see host_tool_wrapper.sh.in for why RPATH fails).
get_filename_component(_upbge_host_build "${UPBGE_ANDROID_HOST_TOOLS_DIR}" DIRECTORY)
load_cache("${_upbge_host_build}" READ_WITH_PREFIX _upbge_host_ LIBDIR)
set(_upbge_host_lib_dirs)
if(_upbge_host_LIBDIR)
  file(GLOB _upbge_host_libs LIST_DIRECTORIES false "${_upbge_host_LIBDIR}/*/lib/*.so*")
  foreach(_lib ${_upbge_host_libs})
    get_filename_component(_dir "${_lib}" DIRECTORY)
    list(APPEND _upbge_host_lib_dirs "${_dir}")
  endforeach()
  list(REMOVE_DUPLICATES _upbge_host_lib_dirs)
  list(SORT _upbge_host_lib_dirs)
endif()
list(JOIN _upbge_host_lib_dirs ":" UPBGE_ANDROID_HOST_LIBRARY_PATH)
unset(_upbge_host_build)
unset(_upbge_host_LIBDIR)
unset(_upbge_host_libs)
unset(_upbge_host_lib_dirs)

function(add_executable name)
  _add_executable(${name} ${ARGN})
  if(name IN_LIST UPBGE_ANDROID_HOST_TOOLS)
    set(_host_tool "${UPBGE_ANDROID_HOST_TOOLS_DIR}/${name}")
    if(NOT EXISTS "${_host_tool}")
      message(FATAL_ERROR "host tool missing: ${_host_tool} (build it in the host tree first)")
    endif()
    set(UPBGE_TOOL "${name}")
    set(UPBGE_HOST_TOOL "${_host_tool}")
    set(UPBGE_HOST_LIBRARY_PATH "${UPBGE_ANDROID_HOST_LIBRARY_PATH}")
    set(_wrapper "${CMAKE_BINARY_DIR}/android_host_tools/${name}")
    # Rewritten only when its content changes, so it does not force relinks.
    configure_file("${CMAKE_CURRENT_FUNCTION_LIST_DIR}/host_tool_wrapper.sh.in" "${_wrapper}"
      @ONLY
      FILE_PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE
                       WORLD_READ WORLD_EXECUTE
    )
    # POST_BUILD only runs on relink: relink when the host tool or the wrapper
    # changes, which also re-runs every generator that depends on the target.
    set_property(TARGET ${name} APPEND PROPERTY LINK_DEPENDS "${_host_tool}" "${_wrapper}")
    add_custom_command(
      TARGET ${name} POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy "${_wrapper}" "$<TARGET_FILE:${name}>"
      COMMENT "Using host ${name}"
      VERBATIM
    )
  endif()
endfunction()

# --- Empty link stubs -----------------------------------------------------------
# Libraries Blender's CMake names unconditionally but that do not exist here.
# An empty archive satisfies the linker:
#  - util, pthread: platform_unix.cmake links -lutil and extern/audaspace links
#    -lpthread; Bionic has neither (openpty() and pthreads are in libc).
#  - audaspace-py: WITH_PYTHON_NUMPY is OFF, so audaspace skips its Python
#    binding, yet dependency_targets.cmake still links it by name whenever
#    WITH_PYTHON is ON. Nothing references its symbols (see README, TODO).
set(_upbge_android_stubs "${CMAKE_BINARY_DIR}/android_stubs")
foreach(_lib util pthread audaspace-py)
  if(NOT EXISTS "${_upbge_android_stubs}/lib${_lib}.a")
    file(WRITE "${_upbge_android_stubs}/lib${_lib}.a" "!<arch>\n")
  endif()
endforeach()
unset(_lib)
link_directories("${_upbge_android_stubs}")

# --- oiiotool ------------------------------------------------------------------
# dependency_targets.cmake reads the location of OpenImageIO::oiiotool, which only
# the Python tests use. The deps recipe builds OIIO without tools (an ARM oiiotool
# cannot run on the host), so stand in for it. Remove this if the recipe ever sets
# OIIO_BUILD_TOOLS=ON: the OIIO config would then define the target itself.
add_executable(OpenImageIO::oiiotool IMPORTED GLOBAL)
set_target_properties(OpenImageIO::oiiotool PROPERTIES
  IMPORTED_LOCATION "${_upbge_android_stubs}/oiiotool-not-built"
)
unset(_upbge_android_stubs)

# --- Find hints ------------------------------------------------------------------
# The Find modules OpenColorIO installs (Findpystring, Findminizip-ng) search only
# <Name>_ROOT and the system prefixes, never <root>/include/<name>.
set(pystring_ROOT "${UPBGE_ANDROID_DEPS_PREFIX}")
set(minizip-ng_ROOT "${UPBGE_ANDROID_DEPS_PREFIX}")

# FindPythonLibsUnix looks for include/python3.13 below its HINTS only; re-rooted
# system prefixes give <root>/include/include/python3.13, so without a root the
# headers are never found. That root also makes its find_program() pick the ARM
# python3 the recipe installs in <root>/bin, and the build runs PYTHON_EXECUTABLE
# (discover_nodes.py): fix it to the host interpreter from PATH first.
set(PYTHON_ROOT_DIR "${UPBGE_ANDROID_DEPS_PREFIX}")
find_program(PYTHON_EXECUTABLE NAMES python3.13 python3
  NO_PACKAGE_ROOT_PATH NO_CMAKE_PATH NO_CMAKE_ENVIRONMENT_PATH NO_CMAKE_SYSTEM_PATH
  NO_CMAKE_FIND_ROOT_PATH
)
if(NOT PYTHON_EXECUTABLE)
  message(FATAL_ERROR "no host python3 in PATH")
endif()

# Bare -l<name> entries from pkg-config results (shaderc_combined, intl, ...)
# resolve in the deps prefix.
link_directories("${UPBGE_ANDROID_DEPS_PREFIX}/lib")

# --- Static link closure ----------------------------------------------------------
# Without LIBDIR, Blender's Find modules return one archive per library, but the
# deps prefix is all static: libsndfile.a needs FLAC/Ogg/Vorbis/Opus, libpython
# needs libintl, and so on. pkg-config --static knows the closure; every archive
# it names that exists in the prefix is added to the player. lld resolves archives
# in any order and pulls only members that satisfy an undefined symbol, so the
# extra entries cost link time, nothing at run time. sqlite3 and expat are listed
# on their own: CPython links them for _sqlite3 and pyexpat (MODLIBS), but
# python-embed.pc omits them.
set(UPBGE_ANDROID_LINK_CLOSURE_MODULES
  sndfile python-3.13-embed sqlite3 expat freetype2 OpenImageIO OpenColorIO OpenEXR
  libavformat libavcodec libavdevice libavfilter libswscale libswresample libavutil
  openal fftw3f fftw3 libtiff-4 libwebp libpng libjpeg zlib libzstd epoxy
)

function(_upbge_android_link_closure)
  if(NOT TARGET blenderplayer)
    return()
  endif()
  find_package(PkgConfig REQUIRED)
  set(_archives)
  foreach(_module ${UPBGE_ANDROID_LINK_CLOSURE_MODULES})
    execute_process(
      COMMAND "${PKG_CONFIG_EXECUTABLE}" --static --libs-only-l ${_module}
      OUTPUT_VARIABLE _flags
      OUTPUT_STRIP_TRAILING_WHITESPACE
      ERROR_QUIET
      RESULT_VARIABLE _result
    )
    if(NOT _result EQUAL 0)
      continue()
    endif()
    separate_arguments(_flags UNIX_COMMAND "${_flags}")
    foreach(_flag ${_flags})
      string(REGEX REPLACE "^-l" "" _name "${_flag}")
      set(_archive "${UPBGE_ANDROID_DEPS_PREFIX}/lib/lib${_name}.a")
      if(EXISTS "${_archive}")
        list(APPEND _archives "${_archive}")
      endif()
    endforeach()
  endforeach()
  list(REMOVE_DUPLICATES _archives)
  list(LENGTH _archives _count)
  message(STATUS "[upbge-android] static link closure: ${_count} archives")
  # NDK system libraries the static archives need and pkg-config does not
  # report: OpenSLES for OpenAL's audio backend.
  target_link_libraries(blenderplayer PRIVATE ${_archives} OpenSLES)
endfunction()
# Runs once the whole tree is configured, when blenderplayer exists.
cmake_language(DEFER CALL _upbge_android_link_closure)
