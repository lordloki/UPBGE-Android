#!/usr/bin/env bash
# FFTW is Autotools-based; build the single-precision and double-precision APIs.
recipe_fftw3() {
    local ver=3.3.10 src="$SRC_DIR/fftw-$ver"
    download_and_extract "https://www.fftw.org/fftw-$ver.tar.gz" "$src"
    autotools_android "$src" "$BUILD_DIR_BASE/fftw3-$ARCH" \
        --enable-float --enable-threads --disable-fortran \
        --disable-mpi --disable-openmp
}
