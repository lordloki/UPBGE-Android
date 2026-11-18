# Dockerfile — reproducible build environment for UPBGE blenderplayer on Android.
#
# Usage:
#   docker build -t upbge-android-builder .
#   docker run --rm -v $HOME/upbge_android_build_base:/build_base \
#                  -v $PWD:/work \
#                  -w /work \
#                  upbge-android-builder \
#                  make setup build ARCH=arm64-v8a
#
# The volume mount keeps the dependency prefix (~60 GB) outside the container
# so it survives re-builds.
#
# Uses ubuntu:24.04 (noble) because it ships gcc-14 and clang-17 in the base
# repos; ubuntu:22.04 (jammy) does not have gcc-14 without a PPA.

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Host toolchain (GCC 14 + Clang 17), build tools, JDK 17.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        gcc-14 g++-14 \
        clang-17 clang-tidy-17 clang-format-17 \
        cmake ninja-build \
        git curl wget unzip zip \
        python3 python3-pip python3-venv \
        openjdk-17-jdk-headless \
        pkg-config autoconf automake libtool \
        bison flex \
        texinfo \
        ca-certificates \
        file \
        openssh-client \
        && rm -rf /var/lib/apt/lists/*

# Wire /usr/bin/gcc and /usr/bin/clang to the right versions.
RUN update-alternatives --install /usr/bin/gcc    gcc    /usr/bin/gcc-14    100 \
 && update-alternatives --install /usr/bin/g++    g++    /usr/bin/g++-14    100 \
 && update-alternatives --install /usr/bin/clang  clang  /usr/bin/clang-17  100 \
 && update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-17 100

# Android SDK + command-line tools + NDK r26d.
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_NDK_VERSION=r26d
ENV ANDROID_NDK_HOME=${ANDROID_HOME}/ndk/${ANDROID_NDK_VERSION}
ENV ANDROID_NDK_ROOT=${ANDROID_NDK_HOME}
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH="${ANDROID_HOME}/platform-tools:${ANDROID_NDK_HOME}:${PATH}"

RUN mkdir -p ${ANDROID_HOME} \
    && cd /tmp \
    && wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip \
    && unzip -q commandlinetools-linux-11076708_latest.zip -d ${ANDROID_HOME} \
    && mkdir -p ${ANDROID_HOME}/cmdline-tools/latest \
    && mv ${ANDROID_HOME}/cmdline-tools/bin    ${ANDROID_HOME}/cmdline-tools/latest/bin \
    && mv ${ANDROID_HOME}/cmdline-tools/lib    ${ANDROID_HOME}/cmdline-tools/latest/lib \
    && (mv ${ANDROID_HOME}/cmdline-tools/NOTICE        ${ANDROID_HOME}/cmdline-tools/latest/NOTICE        2>/dev/null || true) \
    && (mv ${ANDROID_HOME}/cmdline-tools/source.properties ${ANDROID_HOME}/cmdline-tools/latest/source.properties 2>/dev/null || true) \
    && rm commandlinetools-linux-11076708_latest.zip

RUN yes | ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager --licenses > /dev/null \
    && ${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager \
        "platform-tools" \
        "platforms;android-34" \
        "build-tools;34.0.0" \
        "ndk;${ANDROID_NDK_VERSION}"

# Pre-source env.sh in every shell so build.py sees the right vars.
WORKDIR /work
COPY build_files/android/env.sh /opt/env.sh
RUN echo 'source /opt/env.sh' >> /etc/bash.bashrc

CMD ["bash"]
