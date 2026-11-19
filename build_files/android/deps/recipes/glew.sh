#!/usr/bin/env bash
# Desktop GLEW is not an Android GLES loader and is not linked by the player.
recipe_glew() {
    echo "Skipping GLEW: UPBGE Android uses GLES/EGL entry points, not desktop GLEW."
}
