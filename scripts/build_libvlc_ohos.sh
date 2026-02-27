#!/bin/bash

# Source environment setup
source "$(dirname "$0")/build_ohos.sh"

# Fix broken OpenHarmony diff tool by removing it from PATH
export PATH=$(echo "$PATH" | sed -e 's/:\/home\/francesco\/command-line-tools\/sdk\/default\/openharmony\/toolchains//g' -e 's/\/home\/francesco\/command-line-tools\/sdk\/default\/openharmony\/toolchains://g')

# Setup variables
export VLC_PREFIX="$(pwd)/vlc_install"
export TARGET_TUPLE="aarch64-linux-ohos"
export CONTRIB_DIR="$(pwd)/libvlc/contrib/aarch64-linux-ohos"

echo "============================================="
echo "Configuring libVLC..."
echo "============================================="

cd libvlc || exit 1

echo "Running bootstrap..."
./bootstrap

echo "Patching autotools/config.sub..."
sed -i -e 's/linux-android\*/linux-android\*|linux-ohos\*|ohos\*/g' -e 's/android\*/android\* | ohos\*/g' autotools/config.sub

echo "Running configure..."
./configure \
    --host=${TARGET_TUPLE} \
    --prefix=${VLC_PREFIX} \
    --with-contrib=${CONTRIB_DIR} \
    --disable-a52 \
    --disable-xcb \
    --disable-qt \
    --disable-skins2 \
    --disable-vlc \
    --enable-nls=no \
    --disable-alsa \
    --disable-pulse \
    --disable-jack \
    --disable-sndio \
    --disable-wayland \
    --disable-x11 \
    --disable-v4l2 \
    --disable-lua \
    --enable-ohos

echo "Configure finished with code $?"
