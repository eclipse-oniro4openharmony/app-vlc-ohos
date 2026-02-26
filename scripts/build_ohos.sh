#!/bin/bash

# Usage message
usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "This script sets up the environment variables for cross-compiling VLC for OpenHarmony."
    echo "It also verifies that the required SDK and NDK components are present."
    echo ""
    echo "Options:"
    echo "  --help    Show this help message"
    exit 0
}

# Parse arguments
if [[ "$1" == "--help" ]]; then
    usage
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

export CFLAGS="--target=${TARGET_ARCH} --sysroot=${OHOS_SYSROOT} -fPIC -Wl,-z,max-page-size=16384"
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

if [ $FAILED -eq 1 ]; then
    echo "Environment verification FAILED."
    exit 1
fi

echo "Environment verification successful."
echo "Target: ${TARGET_ARCH}"
echo "CC: ${CC}"
$CC --version | head -n 1