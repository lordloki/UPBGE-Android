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

function(add_executable name)
  _add_executable(${name} ${ARGN})
  if(name IN_LIST UPBGE_ANDROID_HOST_TOOLS)
    set(_host_tool "${UPBGE_ANDROID_HOST_TOOLS_DIR}/${name}")
    if(NOT EXISTS "${_host_tool}")
      message(FATAL_ERROR "host tool missing: ${_host_tool} (build it in the host tree first)")
    endif()
    # POST_BUILD only runs on relink: without this a rebuilt host tool would
    # never replace the stale copy.
    set_property(TARGET ${name} APPEND PROPERTY LINK_DEPENDS "${_host_tool}")
    add_custom_command(
      TARGET ${name} POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy "${_host_tool}" "$<TARGET_FILE:${name}>"
      COMMENT "Using host ${name}"
      VERBATIM
    )
  endif()
endfunction()

# --- libutil --------------------------------------------------------------------
# platform_unix.cmake links -lutil unconditionally; Bionic has no libutil
# (openpty() and friends are in libc). An empty archive satisfies the linker.
set(_upbge_android_stubs "${CMAKE_BINARY_DIR}/android_stubs")
if(NOT EXISTS "${_upbge_android_stubs}/libutil.a")
  file(WRITE "${_upbge_android_stubs}/libutil.a" "!<arch>\n")
endif()
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
# extra entries cost link time, nothing at run time.
set(UPBGE_ANDROID_LINK_CLOSURE_MODULES
  sndfile python-3.13-embed freetype2 OpenImageIO OpenColorIO OpenEXR
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
