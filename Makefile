# Makefile — convenience wrapper around build_files/android/build.py
#
# Usage:
#   make setup-host          # install host prereqs (detects Ubuntu/openSUSE/Fedora)
#   make setup-sdk           # install Android SDK + NDK r26d
#   make setup               # clone UPBGE + apply patches
#   make deps ARCH=arm64-v8a FEATURE=player-only
#   make build-player ARCH=arm64-v8a
#   make build-full  ARCH=arm64-v8a
#   make package    ARCH=arm64-v8a FEATURE=player-only
#   make verify     ARCH=arm64-v8a FEATURE=player-only
#   make deploy     ARCH=arm64-v8a FEATURE=player-only
#   make clean-build ARCH=arm64-v8a FEATURE=player-only
#   make clean-all
#
# Default ARCH = arm64-v8a, default FEATURE = player-only.

ARCH      ?= arm64-v8a
FEATURE   ?= player-only
JOBS      ?= $(shell nproc)
BUILD_BASE ?= $(HOME)/upbge_android_build_base

ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
PY   := python3 $(ROOT)/build_files/android/build.py

.PHONY: setup-host setup-sdk setup deps build-player build-full package verify deploy \
	clean-build clean-all env-check

env-check:
	@bash -c 'source $(ROOT)/build_files/android/env.sh && env_check'

setup-host:
	@bash $(ROOT)/scripts/setup_host.sh

setup-sdk:
	@bash $(ROOT)/scripts/install_android_sdk.sh

setup:
	@bash $(ROOT)/scripts/fetch_upbge.sh

deps:
	@ARCH=$(ARCH) FEATURE=$(FEATURE) JOBS=$(JOBS) \
	  bash $(ROOT)/build_files/android/deps/build.sh

build-player:
	@$(PY) player-only --arch $(ARCH) --jobs $(JOBS)

build-full:
	@$(PY) full --arch $(ARCH) --jobs $(JOBS)

package:
	@$(PY) $(FEATURE) --arch $(ARCH) --repackage --jobs $(JOBS)
	@python3 $(ROOT)/scripts/verify_build.py \
	  --arch $(ARCH) -v \
	  "$(BUILD_BASE)/android_apk_stage_$(FEATURE)_$(ARCH)"

verify:
	@python3 $(ROOT)/scripts/verify_build.py \
	  --arch $(ARCH) -v \
	  "$(BUILD_BASE)/android_apk_stage_$(FEATURE)_$(ARCH)"

deploy:
	@ARCH=$(ARCH) FEATURE=$(FEATURE) \
	  bash $(ROOT)/build_files/android/deploy.sh --run --log 10 --shot

clean-build:
	@$(PY) $(FEATURE) --arch $(ARCH) --clean --jobs $(JOBS)

clean-all:
	rm -rf "$(BUILD_BASE)/build_android_$(FEATURE)_$(ARCH)" \
	       "$(BUILD_BASE)/build_host_tools_$(FEATURE)" \
	       "$(BUILD_BASE)/android_apk_stage_$(FEATURE)_$(ARCH)"
