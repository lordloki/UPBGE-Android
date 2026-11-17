#!/usr/bin/env bash
# Generate the remaining recipe stubs. Each one documents the source URL
# and the Wanderson reference, ready for a contributor to fill in.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

declare -A URLS=(
    [gettext]="https://ftp.gnu.org/pub/gnu/gettext/gettext-0.22.5.tar.gz"
    [sqlite]="https://www.sqlite.org/2024/sqlite-autoconf-3450100.tar.gz"
    [boost]="https://boostorg.jfrog.io/artifactory/main/release/1.84.0/source/boost_1_84_0.tar.gz"
    [openexr]="https://github.com/AcademySoftwareFoundation/openexr/archive/refs/tags/v3.2.4.tar.gz"
    [openjpeg]="https://github.com/uclouvain/openjpeg/archive/refs/tags/v2.5.2.tar.gz"
    [tiff]="https://download.osgeo.org/libtiff/tiff-4.6.0.tar.gz"
    [libwebp]="https://github.com/webmproject/libwebp/archive/refs/tags/v1.3.2.tar.gz"
    [fftw3]="https://www.fftw.org/fftw-3.3.10.tar.gz"
    [sndfile]="https://github.com/libsndfile/libsndfile/releases/download/1.2.2/libsndfile-1.2.2.tar.xz"
    [flac]="https://downloads.xiph.org/releases/flac/flac-1.4.3.tar.xz"
    [vorbis]="https://downloads.xiph.org/releases/vorbis/libvorbis-1.3.7.tar.gz"
    [ogg]="https://downloads.xiph.org/releases/ogg/libogg-1.3.5.tar.gz"
    [opus]="https://archive.mozilla.org/pub/opus/opus-1.5.1.tar.gz"
    [sdl2]="https://github.com/libsdl-org/SDL/releases/download/release-2.30.5/SDL2-2.30.5.tar.gz"
    [jpeg-xt]="https://github.com/osamu86/jpegxt/archive/refs/tags/v1.0.tar.gz"
    [glew]="https://github.com/nigels-com/glew/releases/download/glew-2.2.0/glew-2.2.0.tgz"
    [shaderc]="https://github.com/google/shaderc/archive/refs/tags/v2024.1.tar.gz"
    [spirv-tools]="https://github.com/KhronosGroup/SPIRV-Tools/archive/refs/tags/v2024.1.tar.gz"
    # full-only extras
    [tbb]="https://github.com/oneapi-src/oneTBB/archive/refs/tags/v2021.11.0.tar.gz"
    [openvdb]="https://github.com/AcademySoftwareFoundation/openvdb/archive/refs/tags/v11.0.0.tar.gz"
    [openimageio]="https://github.com/OpenImageIO/oiio/archive/refs/tags/v2.5.12.0.tar.gz"
    [opensubdiv]="https://github.com/PixarAnimationStudios/OpenSubdiv/archive/refs/tags/v3_6_0.tar.gz"
    [embree]="https://github.com/embree/embree/archive/refs/tags/v4.3.1.tar.gz"
    [ceres]="https://github.com/ceres-solver/ceres-solver/archive/refs/tags/2.2.0.tar.gz"
    [gmp]="https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz"
    [mpfr]="https://ftp.gnu.org/gnu/mpfr/mpfr-4.2.1.tar.xz"
    [pugixml]="https://github.com/zeux/pugixml/archive/refs/tags/v1.14.tar.gz"
    [openpgl]="https://github.com/OpenPGL/openpgl/archive/refs/tags/v0.5.0.tar.gz"
    [manifold]="https://github.com/elalish/manifold/archive/refs/tags/v2.4.1.tar.gz"
    [draco]="https://github.com/google/draco/archive/refs/tags/1.5.7.tar.gz"
    [openimagedenoise]="https://github.com/OpenImageDenoise/oidn/archive/refs/tags/v2.2.2.tar.gz"
    [openshadinglanguage]="https://github.com/AcademySoftwareFoundation/OpenShadingLanguage/archive/refs/tags/v1.13.10.0.tar.gz"
    [pystring]="https://github.com/imageworks/pystring/archive/refs/tags/1.1.4.tar.gz"
    [hdf5]="https://support.hdfgroup.org/releases/hdf5/v1_14/v1_14_3/downloads/hdf5-1.14.3.tar.gz"
    [alembic]="https://github.com/alembic/alembic/archive/refs/tags/1.8.6.tar.gz"
    [materialx]="https://github.com/AcademySoftwareFoundation/MaterialX/archive/refs/tags/v1.39.1.tar.gz"
    [usd]="https://github.com/PixarAnimationStudios/USD/archive/refs/tags/v24.05.tar.gz"
    [potrace]="https://downloads.sourceforge.net/potrace/potrace-1.16.tar.gz"
    [pcre2]="https://github.com/PCRE2Project/pcre2/archive/refs/tags/pcre2-10.43.tar.gz"
    [xml2]="https://gitlab.gnome.org/GNOME/libxml2/-/archive/v2.12.5/libxml2-v2.12.5.tar.gz"
    [iconv]="https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.17.tar.gz"
    [intl]="https://ftp.gnu.org/pub/gnu/gettext/gettext-0.22.5.tar.gz"
    [freetype_extras]="https://downloads.sourceforge.net/freetype/freetype-2.13.2.tar.gz"
)

declare -A NOTES=(
    [openexr]="Expects zlib + libdeflate. Use Imath from the same tag."
    [openimageio]="Heavy. Requires boost, libtiff, openexr, libjpeg, libpng. Wanderson enables only the readers needed by Blender."
    [openvdb]="Requires boost, tbb, zlib, blosc (drop blosc on Android)."
    [openimagedenoise]="Apply build_files/android/patches/oidn_android.diff before configuring."
    [ceres]="Drop TBB if WITH_TBB=OFF in player_only; use std::thread backend."
    [usd]="Huge. Wanderson enables only the Blender-relevant modules. Disable tests, docs, Python bindings except the ones UPBGE calls."
    [hdf5]="Required by Alembic when WITH_ALEMBIC_HDF5=ON."
    [alembic]="Requires ilmbase/openexr headers + hdf5."
    [materialx]="Build the C++ core only; skip the shader generators that need Python at configure time."
    [boost]="Bootstrap with --without-{python,mpi,graph,log,test,wave}. Build only the static libraries: filesystem, system, thread, regex, date_time, iostreams, program_options."
)

for name in "${!URLS[@]}"; do
    out="$HERE/${name}.sh"
    if [ -f "$out" ]; then continue; fi
    url="${URLS[$name]}"
    note="${NOTES[$name]:-}"
    cat > "$out" <<EOF
#!/usr/bin/env bash
# deps/recipes/${name}.sh
#
# Source: $url
# Reference: Wanderson's build_files/android/deps/build.sh
# ${note}
#
# STATUS: stub. The skeleton below will fetch and call cmake_android; you
#         likely need to add feature toggles, patch steps, or post-install
#         fixes. See the README in this directory for the contract.
recipe_${name}() {
    local src="\$SRC_DIR/${name}"
    if [ ! -d "\$src" ]; then
        download_and_extract "$url" "\$src"
    fi
    # If a patch exists, apply it now:
    #   patch -d "\$src" -p1 < "\$UPBGE_ANDROID_ROOT/build_files/android/patches/${name}_android.diff"
    cmake_android "\$src" "\$BUILD_DIR_BASE/${name}-\$ARCH"
}
EOF
done

echo "wrote $(ls "$HERE" | wc -l) recipe files in $HERE"
