#!/usr/bin/env bash
# TIFF library, zlib + JPEG codecs only (Blender's build_environment set).
recipe_tiff() {
    local ver=4.6.0
    local src="$SRC_DIR/tiff-$ver"
    download_and_extract "https://download.osgeo.org/libtiff/tiff-$ver.tar.gz" "$src"
    # Codec options carry no "tiff-" prefix in libtiff 4.6 (cmake/*Codec.cmake);
    # the prefixed names were silently ignored and codecs were auto-detected.
    cmake_android "$src" "$BUILD_DIR_BASE/tiff-$ARCH" \
        -Dtiff-tools=OFF -Dtiff-tests=OFF -Dtiff-docs=OFF -Dtiff-contrib=OFF \
        -Djbig=OFF -Dlerc=OFF -Dwebp=OFF -Dlzma=OFF -Dlibdeflate=OFF \
        -Dzstd=OFF -Dzlib=ON -Djpeg=ON
    # A static libtiff exports links to ZLIB::ZLIB, JPEG::JPEG and CMath::CMath
    # but its TiffConfig.cmake never imports them ("TODO: import dependencies"),
    # so OpenImageIO (and Blender through OIIO's config) fail to configure.
    local cfg="$DEPS_PREFIX/lib/cmake/tiff/TiffConfig.cmake"
    grep -q '# TODO: import dependencies' "$cfg" || {
        echo "TiffConfig.cmake layout changed; revisit the dependency fixup" >&2
        return 1
    }
    sed -i 's|^    # TODO: import dependencies$|    include(CMakeFindDependencyMacro)\
    find_dependency(ZLIB)\
    find_dependency(JPEG)\
    if(NOT TARGET CMath::CMath)\
        add_library(CMath::CMath INTERFACE IMPORTED)\
        set_target_properties(CMath::CMath PROPERTIES INTERFACE_LINK_LIBRARIES m)\
    endif()|' "$cfg"
}
