# Makefile — convenience wrapper around build_files/android/build.py
#
# Usage:
#   make setup-host          # install host prereqs (detects Ubuntu/openSUSE/Fedora)
#   make setup-sdk           # install Android SDK + NDK r27d
#   make setup               # clone UPBGE + apply patches
#   make deps ARCH=arm64-v8a # cross-compile dependency prefix (one-time, hours;
#                            # resumes after a failure, DEPS_ARGS="--only X|--force")
#   make build               # build blenderplayer (player-only, arm64-v8a)
#   make package             # assemble + verify the player bundle
#   make verify              # re-run verify_build.py on the bundle
#   make deploy              # install + run on a connected device
#   make clean-build         # wipe the build tree (keep deps prefix)
#   make clean-all           # wipe build + host tools + apk stage
#
# arm64-v8a + player-only is the only supported configuration.

ARCH      ?= arm64-v8a
JOBS      ?= $(shell nproc)
BUILD_BASE ?= $(HOME)/upbge_android_build_base

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
PY   := python3 $(ROOT)/build_files/android/build.py

.PHONY: setup-host setup-sdk setup deps build package verify deploy \
        clean-build clean-all env-check

env-check:
	@bash -c 'source $(ROOT)/build_files/android/env.sh && env_check'

setup-host:
	@bash $(ROOT)/scripts/setup_host.sh

setup-sdk:
	@bash $(ROOT)/scripts/install_android_sdk.sh

setup:
	@bash $(ROOT)/scripts/fetch_upbge.sh

# DEPS_ARGS is passed through, e.g. make deps DEPS_ARGS="--only ffmpeg"
deps:
	@ARCH=$(ARCH) JOBS=$(JOBS) BUILD_BASE=$(BUILD_BASE) \
	  bash $(ROOT)/build_files/android/deps/build.sh $(DEPS_ARGS)

build:
	@$(PY) player-only --arch $(ARCH) --jobs $(JOBS)

package:
	@$(PY) player-only --arch $(ARCH) --repackage --jobs $(JOBS)
	@python3 $(ROOT)/scripts/verify_build.py \
	  --arch $(ARCH) -v \
	  "$(BUILD_BASE)/android_apk_stage_player-only_$(ARCH)"

verify:
	@python3 $(ROOT)/scripts/verify_build.py \
	  --arch $(ARCH) -v \
	  "$(BUILD_BASE)/android_apk_stage_player-only_$(ARCH)"

deploy:
	@ARCH=$(ARCH) FEATURE=player-only \
	  bash $(ROOT)/build_files/android/deploy.sh --run --log 10 --shot

clean-build:
	@$(PY) player-only --arch $(ARCH) --clean --jobs $(JOBS)

clean-all:
	rm -rf "$(BUILD_BASE)/build_android_player-only_$(ARCH)" \
	       "$(BUILD_BASE)/build_host_tools_player-only" \
	       "$(BUILD_BASE)/android_apk_stage_player-only_$(ARCH)"
