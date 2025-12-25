#!/bin/bash
#
# Cross-compile libusb for Android
# Required for CCID USB communication in OpenSC on Android
#
# Prerequisites:
# - Android NDK installed
# - Set ANDROID_NDK_ROOT environment variable
#
# Usage: ./build-libusb-android.sh [ABI]
#   ABI can be: arm64-v8a, armeabi-v7a, x86, x86_64, or "all" for all architectures

set -e

# Configuration
LIBUSB_VERSION="1.0.27"
LIBUSB_URL="https://github.com/libusb/libusb/releases/download/v${LIBUSB_VERSION}/libusb-${LIBUSB_VERSION}.tar.bz2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build-android"
INSTALL_PREFIX="${BUILD_DIR}/install"

# Android NDK configuration
if [ -z "$ANDROID_NDK_ROOT" ]; then
    echo "Error: ANDROID_NDK_ROOT is not set"
    echo "Please set ANDROID_NDK_ROOT to your Android NDK installation path"
    echo "Example: export ANDROID_NDK_ROOT=/path/to/android-ndk"
    exit 1
fi

if [ ! -d "$ANDROID_NDK_ROOT" ]; then
    echo "Error: ANDROID_NDK_ROOT directory does not exist: $ANDROID_NDK_ROOT"
    exit 1
fi

# Determine NDK version and toolchain directory
NDK_TOOLCHAIN="${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt"
if [ "$(uname -s)" = "Darwin" ]; then
    NDK_HOST_TAG="darwin-x86_64"
elif [ "$(uname -s)" = "Linux" ]; then
    NDK_HOST_TAG="linux-x86_64"
else
    echo "Error: Unsupported host OS: $(uname -s)"
    exit 1
fi

TOOLCHAIN="${NDK_TOOLCHAIN}/${NDK_HOST_TAG}"
if [ ! -d "$TOOLCHAIN" ]; then
    echo "Error: Toolchain not found at: $TOOLCHAIN"
    exit 1
fi

# Android API level (21 = Android 5.0, minimum for modern USB features)
API_LEVEL=21

# Function to download and extract libusb
download_libusb() {
    echo "=== Downloading libusb ${LIBUSB_VERSION} ==="
    mkdir -p "${BUILD_DIR}"
    cd "${BUILD_DIR}"

    if [ ! -f "libusb-${LIBUSB_VERSION}.tar.bz2" ]; then
        echo "Downloading libusb..."
        curl -L -o "libusb-${LIBUSB_VERSION}.tar.bz2" "${LIBUSB_URL}"
    else
        echo "libusb tarball already exists, skipping download"
    fi

    if [ ! -d "libusb-${LIBUSB_VERSION}" ]; then
        echo "Extracting libusb..."
        tar xjf "libusb-${LIBUSB_VERSION}.tar.bz2"
    else
        echo "libusb source already extracted, skipping"
    fi
}

# Function to build libusb for a specific ABI
build_for_abi() {
    local ABI=$1
    local ARCH=""
    local TARGET=""

    case "$ABI" in
        arm64-v8a)
            ARCH="arm64"
            TARGET="aarch64-linux-android"
            ;;
        armeabi-v7a)
            ARCH="arm"
            TARGET="armv7a-linux-androideabi"
            ;;
        x86)
            ARCH="x86"
            TARGET="i686-linux-android"
            ;;
        x86_64)
            ARCH="x86_64"
            TARGET="x86_64-linux-android"
            ;;
        *)
            echo "Error: Unknown ABI: $ABI"
            echo "Supported ABIs: arm64-v8a, armeabi-v7a, x86, x86_64"
            exit 1
            ;;
    esac

    echo ""
    echo "=== Building libusb for ${ABI} ==="

    # Setup build directory for this ABI
    local ABI_BUILD_DIR="${BUILD_DIR}/libusb-${LIBUSB_VERSION}/build-${ABI}"
    local ABI_INSTALL_DIR="${INSTALL_PREFIX}/${ABI}"

    mkdir -p "${ABI_BUILD_DIR}"
    cd "${ABI_BUILD_DIR}"

    # Set up toolchain paths
    export PATH="${TOOLCHAIN}/bin:${PATH}"
    export AR="${TOOLCHAIN}/bin/llvm-ar"
    export AS="${TOOLCHAIN}/bin/llvm-as"
    export CC="${TOOLCHAIN}/bin/${TARGET}${API_LEVEL}-clang"
    export CXX="${TOOLCHAIN}/bin/${TARGET}${API_LEVEL}-clang++"
    export LD="${TOOLCHAIN}/bin/ld"
    export RANLIB="${TOOLCHAIN}/bin/llvm-ranlib"
    export STRIP="${TOOLCHAIN}/bin/llvm-strip"
    export NM="${TOOLCHAIN}/bin/llvm-nm"

    # Configure flags
    export CFLAGS="-fPIC -DANDROID -D__ANDROID_API__=${API_LEVEL}"
    export CPPFLAGS="-fPIC -DANDROID -D__ANDROID_API__=${API_LEVEL}"
    export LDFLAGS=""

    # Run configure
    echo "Configuring libusb for ${ABI}..."
    ../../configure \
        --host="${TARGET}" \
        --prefix="${ABI_INSTALL_DIR}" \
        --enable-static \
        --enable-shared \
        --disable-udev \
        --enable-system-log

    # Build
    echo "Building libusb for ${ABI}..."
    make -j$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

    # Install
    echo "Installing libusb for ${ABI}..."
    make install

    echo "=== Build complete for ${ABI} ==="
    echo "Libraries installed to: ${ABI_INSTALL_DIR}"
    echo "  - Static: ${ABI_INSTALL_DIR}/lib/libusb-1.0.a"
    echo "  - Shared: ${ABI_INSTALL_DIR}/lib/libusb-1.0.so"
    echo "  - Headers: ${ABI_INSTALL_DIR}/include/libusb-1.0"
}

# Function to create a summary
create_summary() {
    echo ""
    echo "=============================================="
    echo "libusb Android build summary"
    echo "=============================================="
    echo "libusb version: ${LIBUSB_VERSION}"
    echo "Install prefix: ${INSTALL_PREFIX}"
    echo ""
    echo "Built architectures:"

    for abi_dir in "${INSTALL_PREFIX}"/*; do
        if [ -d "$abi_dir" ]; then
            local abi=$(basename "$abi_dir")
            if [ -f "${abi_dir}/lib/libusb-1.0.a" ]; then
                echo "  ✓ ${abi}"
                echo "    Static:  ${abi_dir}/lib/libusb-1.0.a"
                echo "    Shared:  ${abi_dir}/lib/libusb-1.0.so"
                echo "    Headers: ${abi_dir}/include/libusb-1.0"
            fi
        fi
    done

    echo ""
    echo "To use these libraries in your Android project:"
    echo "1. Copy the libraries for your target ABI to your project's jniLibs directory"
    echo "2. Include headers from: ${INSTALL_PREFIX}/[ABI]/include/libusb-1.0"
    echo "3. Link with: -lusb-1.0"
    echo ""
    echo "For OpenSC Android build, you can reference these paths in your build configuration."
    echo "=============================================="
}

# Main execution
main() {
    local TARGET_ABI="${1:-all}"

    echo "Building libusb for Android"
    echo "NDK: ${ANDROID_NDK_ROOT}"
    echo "API Level: ${API_LEVEL}"
    echo "Target ABI: ${TARGET_ABI}"
    echo ""

    # Download libusb if needed
    download_libusb

    # Build for specified ABI(s)
    if [ "$TARGET_ABI" = "all" ]; then
        for abi in arm64-v8a armeabi-v7a x86 x86_64; do
            build_for_abi "$abi"
        done
    else
        build_for_abi "$TARGET_ABI"
    fi

    # Create summary
    create_summary
}

# Run main function
main "$@"
