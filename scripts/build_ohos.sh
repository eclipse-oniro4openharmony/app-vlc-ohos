#!/bin/bash

# Usage message
usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "This script sets up the environment variables for cross-compiling VLC for OpenHarmony."
    echo "It also verifies that the required SDK and NDK components are present."
    echo ""
    echo "Options:"
    echo "  --help       Show this help message"
    echo "  --contribs   Build third-party dependencies (contribs)"
    exit 0
}

# Parse arguments
BUILD_CONTRIBS=0
if [[ "$1" == "--help" ]]; then
    usage
elif [[ "$1" == "--contribs" ]]; then
    BUILD_CONTRIBS=1
fi

# Environment Variables
export OHOS_SDK_ROOT="/home/francesco/setup-ohos-sdk/linux/20"
export OHOS_NDK="${OHOS_SDK_ROOT}/native"
export OHOS_SYSROOT="${OHOS_NDK}/sysroot"
export OHOS_TOOLCHAIN="${OHOS_NDK}/build/cmake/ohos.toolchain.cmake"
export TARGET_ARCH="aarch64-linux-ohos"

export CC="${OHOS_NDK}/llvm/bin/clang"
export CXX="${OHOS_NDK}/llvm/bin/clang++"
export AR="${OHOS_NDK}/llvm/bin/llvm-ar"
export NM="${OHOS_NDK}/llvm/bin/llvm-nm"
export RANLIB="${OHOS_NDK}/llvm/bin/llvm-ranlib"
export STRIP="${OHOS_NDK}/llvm/bin/llvm-strip"
export STRINGS="${OHOS_NDK}/llvm/bin/llvm-strings"
export OBJDUMP="${OHOS_NDK}/llvm/bin/llvm-objdump"

export CFLAGS="--target=${TARGET_ARCH} --sysroot=${OHOS_SYSROOT} -fPIC"
export LDFLAGS="--target=${TARGET_ARCH} --sysroot=${OHOS_SYSROOT} -Wl,-z,max-page-size=16384"

# Verification Logic
echo "Verifying OpenHarmony SDK/NDK environment..."

check_dir() {
    if [ ! -d "$1" ]; then
        echo "Error: Directory $1 not found."
        return 1
    fi
}

check_file() {
    if [ ! -f "$1" ]; then
        echo "Error: File $1 not found."
        return 1
    fi
}

check_exec() {
    if [ ! -x "$1" ]; then
        echo "Error: Executable $1 not found or not executable."
        return 1
    fi
}

FAILED=0
check_dir "${OHOS_SDK_ROOT}" || FAILED=1
check_dir "${OHOS_NDK}" || FAILED=1
check_dir "${OHOS_SYSROOT}" || FAILED=1
check_file "${OHOS_TOOLCHAIN}" || FAILED=1
check_exec "${CC}" || FAILED=1
check_exec "${CXX}" || FAILED=1
check_exec "${AR}" || FAILED=1
check_exec "${NM}" || FAILED=1
check_exec "${RANLIB}" || FAILED=1
check_exec "${STRIP}" || FAILED=1
check_exec "${STRINGS}" || FAILED=1
check_exec "${OBJDUMP}" || FAILED=1

if [ $FAILED -eq 1 ]; then
    echo "Environment verification FAILED."
    exit 1
fi

echo "Environment verification successful."
echo "Target: ${TARGET_ARCH}"
echo "CC: ${CC}"
$CC --version | head -n 1

build_contribs() {
    echo "============================================="
    echo "Preparing Contrib Build Environment..."
    echo "============================================="
    export TARGET_TUPLE="aarch64-linux-ohos"
    CONTRIB_DIR="$(pwd)/libvlc/contrib/contrib-ohos-${TARGET_TUPLE}"
    
    mkdir -p "${CONTRIB_DIR}"
    cd "${CONTRIB_DIR}" || exit 1
    
    # Run bootstrap
    ../bootstrap --build=x86_64-unknown-linux-gnu --host=${TARGET_TUPLE} --disable-cddb
    
    # Write OpenHarmony toolchain paths to config.mak
    # Fix broken OpenHarmony diff tool by removing it from PATH
    echo "PATH := \$(subst /home/francesco/command-line-tools/sdk/default/openharmony/toolchains:,,\\\$(PATH))" > config.mak
    echo "EXTRA_CFLAGS=${CFLAGS}" >> config.mak
    echo "EXTRA_CXXFLAGS=${CXXFLAGS}" >> config.mak
    echo "EXTRA_LDFLAGS=${LDFLAGS}" >> config.mak
    echo "CC=${CC}" >> config.mak
    echo "CXX=${CXX}" >> config.mak
    echo "AR=${AR}" >> config.mak
    echo "AS=${CC} -c" >> config.mak
    echo "RANLIB=${RANLIB}" >> config.mak
    echo "LD=${LD:-${CC}}" >> config.mak
    echo "NM=${NM}" >> config.mak
    echo "STRIP=${STRIP}" >> config.mak
    echo "STRINGS=${STRINGS}" >> config.mak
    echo "OBJDUMP=${OBJDUMP}" >> config.mak
    echo "PKGS_DISABLE += protobuf lua xcb srt" >> config.mak
    
    echo "Contrib environment prepared in ${CONTRIB_DIR}"
    echo "Check config.mak for toolchain variables."
    cd - > /dev/null
}

if [ $BUILD_CONTRIBS -eq 1 ]; then
    build_contribs
fi