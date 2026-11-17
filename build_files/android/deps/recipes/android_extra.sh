#!/usr/bin/env bash
# deps/recipes/android_extra.sh
#
# Copies the NDK-bundled android_native_app_glue.c and log.h into the deps
# prefix so the GHOST Android backend can include them.
recipe_android_extra() {
    local glue="$ANDROID_NDK_HOME/sources/android/native_app_glue"
    if [ ! -d "$glue" ]; then
        echo "  FATAL: $glue not found in NDK" >&2
        return 1
    fi
    mkdir -p "$DEPS_PREFIX/include/android/native_app_glue"
    cp "$glue"/*.h "$DEPS_PREFIX/include/android/native_app_glue/"
    cp "$glue"/android_native_app_glue.c "$DEPS_PREFIX/include/android/native_app_glue/"
}
