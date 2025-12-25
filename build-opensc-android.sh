#!/bin/bash
#
# Cross-compile OpenSC for Android with libusb support
# This enables CCID USB communication on Android
#
# Prerequisites:
# - Android NDK installed
# - Set ANDROID_NDK_ROOT environment variable
# - libusb built for Android (run build-libusb-android.sh first)
#
# Usage: ./build-opensc-android.sh [ABI]
#   ABI can be: arm64-v8a, armeabi-v7a, x86, x86_64, or "all" for all architectures

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build-android"
LIBUSB_PREFIX="${BUILD_DIR}/install"
OPENSC_INSTALL_PREFIX="${BUILD_DIR}/opensc-install"

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

# Android API level (21 = Android 5.0)
API_LEVEL=21

# Check if OpenSSL is available (optional but recommended)
check_openssl() {
    local ABI=$1
    local OPENSSL_PREFIX="${BUILD_DIR}/openssl-install/${ABI}"

    if [ -d "${OPENSSL_PREFIX}" ] && [ -f "${OPENSSL_PREFIX}/lib/libcrypto.a" ]; then
        echo "Found OpenSSL for ${ABI} at ${OPENSSL_PREFIX}"
        echo "${OPENSSL_PREFIX}"
        return 0
    else
        echo "Warning: OpenSSL not found for ${ABI}. Building without OpenSSL support."
        echo "For full functionality, consider building OpenSSL for Android first."
        echo ""
        return 1
    fi
}

# Function to prepare OpenSC source
prepare_opensc() {
    echo "=== Preparing OpenSC source ==="
    cd "${SCRIPT_DIR}"

    # Check if we need to run bootstrap
    if [ ! -f "configure" ]; then
        echo "Running bootstrap to generate configure script..."
        if [ -f "bootstrap" ]; then
            ./bootstrap
        elif [ -f "bootstrap.ci" ]; then
            ./bootstrap.ci
        else
            echo "Error: Cannot find bootstrap script"
            exit 1
        fi
    fi
}

# Function to build OpenSC for a specific ABI
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
    echo "=== Building OpenSC for ${ABI} ==="

    # Check for libusb
    local LIBUSB_ABI_PREFIX="${LIBUSB_PREFIX}/${ABI}"
    if [ ! -f "${LIBUSB_ABI_PREFIX}/lib/libusb-1.0.a" ]; then
        echo "Error: libusb not found for ${ABI}"
        echo "Please run ./build-libusb-android.sh ${ABI} first"
        exit 1
    fi

    echo "Found libusb at: ${LIBUSB_ABI_PREFIX}"

    # Setup build directory for this ABI
    local ABI_BUILD_DIR="${BUILD_DIR}/opensc-build-${ABI}"
    local ABI_INSTALL_DIR="${OPENSC_INSTALL_PREFIX}/${ABI}"

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
    export CFLAGS="-fPIC -DANDROID -D__ANDROID_API__=${API_LEVEL} -I${LIBUSB_ABI_PREFIX}/include/libusb-1.0"
    export CPPFLAGS="-fPIC -DANDROID -D__ANDROID_API__=${API_LEVEL} -I${LIBUSB_ABI_PREFIX}/include/libusb-1.0"
    export LDFLAGS="-L${LIBUSB_ABI_PREFIX}/lib"
    export LIBS="-lusb-1.0"

    # Check for OpenSSL and add to flags if available
    local OPENSSL_PREFIX=""
    if OPENSSL_PREFIX=$(check_openssl "${ABI}"); then
        export CFLAGS="${CFLAGS} -I${OPENSSL_PREFIX}/include"
        export CPPFLAGS="${CPPFLAGS} -I${OPENSSL_PREFIX}/include"
        export LDFLAGS="${LDFLAGS} -L${OPENSSL_PREFIX}/lib"
        OPENSSL_CONFIGURE_FLAGS="--enable-openssl"
    else
        OPENSSL_CONFIGURE_FLAGS="--disable-openssl"
    fi

    # PKG_CONFIG settings
    export PKG_CONFIG_PATH="${LIBUSB_ABI_PREFIX}/lib/pkgconfig"
    if [ -n "$OPENSSL_PREFIX" ]; then
        export PKG_CONFIG_PATH="${PKG_CONFIG_PATH}:${OPENSSL_PREFIX}/lib/pkgconfig"
    fi
    export PKG_CONFIG_LIBDIR="${PKG_CONFIG_PATH}"

    # Run configure
    echo "Configuring OpenSC for ${ABI}..."
    "${SCRIPT_DIR}/configure" \
        --host="${TARGET}" \
        --prefix="${ABI_INSTALL_DIR}" \
        --sysconfdir=/etc \
        --enable-static \
        --enable-shared \
        --disable-pcsc \
        --disable-cryptotokenkit \
        --disable-ctapi \
        --disable-openct \
        --disable-notify \
        --disable-man \
        --disable-doc \
        --disable-tests \
        ${OPENSSL_CONFIGURE_FLAGS} \
        --with-completiondir="${ABI_INSTALL_DIR}/etc/bash_completion.d"

    # Build
    echo "Building OpenSC for ${ABI}..."
    make -j$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4) V=1

    # Install
    echo "Installing OpenSC for ${ABI}..."
    make install

    # Strip binaries to reduce size
    echo "Stripping binaries for ${ABI}..."
    find "${ABI_INSTALL_DIR}" -name "*.so" -exec ${STRIP} --strip-unneeded {} \; 2>/dev/null || true
    find "${ABI_INSTALL_DIR}" -name "*.a" -exec ${STRIP} --strip-debug {} \; 2>/dev/null || true

    echo "=== Build complete for ${ABI} ==="
    echo "OpenSC installed to: ${ABI_INSTALL_DIR}"
}

# Function to create a summary
create_summary() {
    echo ""
    echo "=============================================="
    echo "OpenSC Android build summary"
    echo "=============================================="
    echo "Install prefix: ${OPENSC_INSTALL_PREFIX}"
    echo ""
    echo "Built architectures:"

    for abi_dir in "${OPENSC_INSTALL_PREFIX}"/*; do
        if [ -d "$abi_dir" ]; then
            local abi=$(basename "$abi_dir")
            if [ -d "${abi_dir}/lib" ]; then
                echo "  ✓ ${abi}"
                echo "    Libraries: ${abi_dir}/lib"
                echo "    Tools:     ${abi_dir}/bin"
                echo "    Config:    ${abi_dir}/etc"
            fi
        fi
    done

    echo ""
    echo "CCID USB Communication:"
    echo "  - libusb support is enabled for direct USB CCID communication"
    echo "  - No PC/SC dependency (PC/SC is disabled for Android)"
    echo "  - Suitable for direct smart card reader access via USB"
    echo ""
    echo "To use OpenSC in your Android app:"
    echo "1. Copy libraries to your app's jniLibs/[ABI]/ directory"
    echo "2. Copy configuration files from etc/ to your app's assets"
    echo "3. Ensure your app has USB_PERMISSION for USB device access"
    echo "4. Use OpenSC JNI wrapper or command-line tools via NDK"
    echo ""
    echo "Required Android permissions in AndroidManifest.xml:"
    echo '  <uses-permission android:name="android.permission.USB_PERMISSION"/>'
    echo '  <uses-feature android:name="android.hardware.usb.host"/>'
    echo ""
    echo "=============================================="
}

# Main execution
main() {
    local TARGET_ABI="${1:-all}"

    echo "Building OpenSC for Android with libusb support"
    echo "NDK: ${ANDROID_NDK_ROOT}"
    echo "API Level: ${API_LEVEL}"
    echo "Target ABI: ${TARGET_ABI}"
    echo ""

    # Prepare OpenSC source
    prepare_opensc

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
