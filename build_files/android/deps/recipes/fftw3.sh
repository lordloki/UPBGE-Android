#!/usr/bin/env bash
# FFTW is Autotools-based. Blender's FindFftw3 requires all three of fftw3f,
# fftw3f_threads and fftw3 (double); a precision is one configure run each.
recipe_fftw3() {
    local ver=3.3.10
    local src="$SRC_DIR/fftw-$ver"
    download_and_extract "https://www.fftw.org/fftw-$ver.tar.gz" "$src"
    autotools_android "$src" "$BUILD_DIR_BASE/fftw3f-$ARCH" \
        --enable-float --enable-threads --disable-fortran \
        --disable-mpi --disable-openmp --disable-doc
    autotools_android "$src" "$BUILD_DIR_BASE/fftw3-$ARCH" \
        --enable-threads --disable-fortran \
        --disable-mpi --disable-openmp --disable-doc
}
