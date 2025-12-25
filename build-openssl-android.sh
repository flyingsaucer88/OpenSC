#!/bin/bash
#
# Cross-compile OpenSSL for Android
# This builds OpenSSL which is required for full OpenSC functionality
#
# Prerequisites:
# - Android NDK installed
# - Set ANDROID_NDK_ROOT environment variable
#
# Usage: ./build-openssl-android.sh [ABI]
#   ABI can be: arm64-v8a, armeabi-v7a, x86, x86_64, or "all" for all architectures

set -e

# Configuration
OPENSSL_VERSION="3.3.0"
OPENSSL_URL="https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build-android"
INSTALL_PREFIX="${BUILD_DIR}/openssl-install"

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

# Function to download and extract OpenSSL
download_openssl() {
    echo "=== Downloading OpenSSL ${OPENSSL_VERSION} ==="
    mkdir -p "${BUILD_DIR}"
    cd "${BUILD_DIR}"

    if [ ! -f "openssl-${OPENSSL_VERSION}.tar.gz" ]; then
        echo "Downloading OpenSSL..."
        curl -L -o "openssl-${OPENSSL_VERSION}.tar.gz" "${OPENSSL_URL}"
    else
        echo "OpenSSL tarball already exists, skipping download"
    fi

    if [ ! -d "openssl-${OPENSSL_VERSION}" ]; then
        echo "Extracting OpenSSL..."
        tar xzf "openssl-${OPENSSL_VERSION}.tar.gz"
    else
        echo "OpenSSL source already extracted, skipping"
    fi
}

# Function to build OpenSSL for a specific ABI
build_for_abi() {
    local ABI=$1
    local ARCH=""
    local TARGET=""
    local OPENSSL_TARGET=""

    case "$ABI" in
        arm64-v8a)
            ARCH="arm64"
            TARGET="aarch64-linux-android"
            OPENSSL_TARGET="android-arm64"
            ;;
        armeabi-v7a)
            ARCH="arm"
            TARGET="armv7a-linux-androideabi"
            OPENSSL_TARGET="android-arm"
            ;;
        x86)
            ARCH="x86"
            TARGET="i686-linux-android"
            OPENSSL_TARGET="android-x86"
            ;;
        x86_64)
            ARCH="x86_64"
            TARGET="x86_64-linux-android"
            OPENSSL_TARGET="android-x86_64"
            ;;
        *)
            echo "Error: Unknown ABI: $ABI"
            echo "Supported ABIs: arm64-v8a, armeabi-v7a, x86, x86_64"
            exit 1
            ;;
    esac

    echo ""
    echo "=== Building OpenSSL for ${ABI} ==="

    # Setup build directory for this ABI
    local ABI_BUILD_DIR="${BUILD_DIR}/openssl-build-${ABI}"
    local ABI_INSTALL_DIR="${INSTALL_PREFIX}/${ABI}"

    # Clean previous build directory
    if [ -d "${ABI_BUILD_DIR}" ]; then
        echo "Cleaning previous build directory..."
        rm -rf "${ABI_BUILD_DIR}"
    fi

    # Copy source to build directory
    echo "Preparing build directory..."
    cp -r "${BUILD_DIR}/openssl-${OPENSSL_VERSION}" "${ABI_BUILD_DIR}"
    cd "${ABI_BUILD_DIR}"

    # Set up toolchain paths
    export PATH="${TOOLCHAIN}/bin:${PATH}"
    export ANDROID_NDK_ROOT="${ANDROID_NDK_ROOT}"

    # Set up compiler and flags
    export CC="${TOOLCHAIN}/bin/${TARGET}${API_LEVEL}-clang"
    export CXX="${TOOLCHAIN}/bin/${TARGET}${API_LEVEL}-clang++"
    export AR="${TOOLCHAIN}/bin/llvm-ar"
    export AS="${TOOLCHAIN}/bin/llvm-as"
    export LD="${TOOLCHAIN}/bin/ld"
    export RANLIB="${TOOLCHAIN}/bin/llvm-ranlib"
    export STRIP="${TOOLCHAIN}/bin/llvm-strip"
    export NM="${TOOLCHAIN}/bin/llvm-nm"

    # Configure OpenSSL
    echo "Configuring OpenSSL for ${ABI}..."
    ./Configure ${OPENSSL_TARGET} \
        -D__ANDROID_API__=${API_LEVEL} \
        --prefix="${ABI_INSTALL_DIR}" \
        --openssldir="${ABI_INSTALL_DIR}/ssl" \
        no-tests \
        no-ui-console \
        shared \
        -fPIC

    # Build OpenSSL
    echo "Building OpenSSL for ${ABI}..."
    make -j$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

    # Install OpenSSL
    echo "Installing OpenSSL for ${ABI}..."
    make install_sw install_ssldirs

    # Create pkg-config file
    echo "Creating pkg-config files..."
    mkdir -p "${ABI_INSTALL_DIR}/lib/pkgconfig"

    # OpenSSL 3.x creates these automatically, but let's ensure they exist
    if [ ! -f "${ABI_INSTALL_DIR}/lib/pkgconfig/openssl.pc" ]; then
        cat > "${ABI_INSTALL_DIR}/lib/pkgconfig/openssl.pc" <<EOF
prefix=${ABI_INSTALL_DIR}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: OpenSSL
Description: Secure Sockets Layer and cryptography libraries and tools
Version: ${OPENSSL_VERSION}
Requires: libssl libcrypto
EOF
    fi

    if [ ! -f "${ABI_INSTALL_DIR}/lib/pkgconfig/libcrypto.pc" ]; then
        cat > "${ABI_INSTALL_DIR}/lib/pkgconfig/libcrypto.pc" <<EOF
prefix=${ABI_INSTALL_DIR}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: OpenSSL-libcrypto
Description: OpenSSL cryptography library
Version: ${OPENSSL_VERSION}
Libs: -L\${libdir} -lcrypto
Libs.private: -ldl -pthread
Cflags: -I\${includedir}
EOF
    fi

    if [ ! -f "${ABI_INSTALL_DIR}/lib/pkgconfig/libssl.pc" ]; then
        cat > "${ABI_INSTALL_DIR}/lib/pkgconfig/libssl.pc" <<EOF
prefix=${ABI_INSTALL_DIR}
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: OpenSSL-libssl
Description: Secure Sockets Layer and cryptography libraries
Version: ${OPENSSL_VERSION}
Requires.private: libcrypto
Libs: -L\${libdir} -lssl
Cflags: -I\${includedir}
EOF
    fi

    echo "=== Build complete for ${ABI} ==="
    echo "OpenSSL installed to: ${ABI_INSTALL_DIR}"
    echo "  - Libraries: ${ABI_INSTALL_DIR}/lib/"
    echo "  - Headers: ${ABI_INSTALL_DIR}/include/openssl/"
    echo "  - pkg-config: ${ABI_INSTALL_DIR}/lib/pkgconfig/"
}

# Function to verify installation
verify_installation() {
    local ABI=$1
    local ABI_INSTALL_DIR="${INSTALL_PREFIX}/${ABI}"

    echo ""
    echo "Verifying installation for ${ABI}..."

    local errors=0

    # Check for libraries
    if [ -f "${ABI_INSTALL_DIR}/lib/libcrypto.so" ] || [ -f "${ABI_INSTALL_DIR}/lib/libcrypto.a" ]; then
        echo "  ✓ libcrypto found"
    else
        echo "  ✗ libcrypto NOT found"
        ((errors++))
    fi

    if [ -f "${ABI_INSTALL_DIR}/lib/libssl.so" ] || [ -f "${ABI_INSTALL_DIR}/lib/libssl.a" ]; then
        echo "  ✓ libssl found"
    else
        echo "  ✗ libssl NOT found"
        ((errors++))
    fi

    # Check for headers
    if [ -f "${ABI_INSTALL_DIR}/include/openssl/opensslv.h" ]; then
        echo "  ✓ Headers found"
    else
        echo "  ✗ Headers NOT found"
        ((errors++))
    fi

    # Check for pkg-config files
    if [ -f "${ABI_INSTALL_DIR}/lib/pkgconfig/openssl.pc" ]; then
        echo "  ✓ pkg-config files found"
    else
        echo "  ✗ pkg-config files NOT found"
        ((errors++))
    fi

    if [ $errors -eq 0 ]; then
        echo "  Installation verified successfully!"
        return 0
    else
        echo "  Warning: Installation has ${errors} issue(s)"
        return 1
    fi
}

# Function to create a summary
create_summary() {
    echo ""
    echo "=============================================="
    echo "OpenSSL Android build summary"
    echo "=============================================="
    echo "OpenSSL version: ${OPENSSL_VERSION}"
    echo "Install prefix: ${INSTALL_PREFIX}"
    echo ""
    echo "Built architectures:"

    for abi_dir in "${INSTALL_PREFIX}"/*; do
        if [ -d "$abi_dir" ]; then
            local abi=$(basename "$abi_dir")
            if [ -f "${abi_dir}/lib/libcrypto.so" ] || [ -f "${abi_dir}/lib/libcrypto.a" ]; then
                echo "  ✓ ${abi}"
                echo "    Libraries:  ${abi_dir}/lib/"
                echo "    Headers:    ${abi_dir}/include/openssl/"
                echo "    pkg-config: ${abi_dir}/lib/pkgconfig/"

                # Show library sizes
                if [ -f "${abi_dir}/lib/libcrypto.so" ]; then
                    local crypto_size=$(du -h "${abi_dir}/lib/libcrypto.so" | cut -f1)
                    local ssl_size=$(du -h "${abi_dir}/lib/libssl.so" | cut -f1)
                    echo "    Size: libcrypto.so (${crypto_size}), libssl.so (${ssl_size})"
                fi
            fi
        fi
    done

    echo ""
    echo "Integration with OpenSC:"
    echo "  The build-opensc-android.sh script will automatically detect"
    echo "  and use these OpenSSL libraries when building OpenSC."
    echo ""
    echo "Manual integration:"
    echo "  CFLAGS=\"-I${INSTALL_PREFIX}/[ABI]/include\""
    echo "  LDFLAGS=\"-L${INSTALL_PREFIX}/[ABI]/lib\""
    echo "  LIBS=\"-lssl -lcrypto\""
    echo ""
    echo "For Android apps:"
    echo "  1. Copy libcrypto.so and libssl.so to jniLibs/[ABI]/"
    echo "  2. Load libraries before using OpenSC:"
    echo "     System.loadLibrary(\"crypto\")"
    echo "     System.loadLibrary(\"ssl\")"
    echo "     System.loadLibrary(\"opensc\")"
    echo "=============================================="
}

# Main execution
main() {
    local TARGET_ABI="${1:-all}"

    echo "Building OpenSSL for Android"
    echo "NDK: ${ANDROID_NDK_ROOT}"
    echo "API Level: ${API_LEVEL}"
    echo "OpenSSL Version: ${OPENSSL_VERSION}"
    echo "Target ABI: ${TARGET_ABI}"
    echo ""

    # Download OpenSSL if needed
    download_openssl

    # Build for specified ABI(s)
    if [ "$TARGET_ABI" = "all" ]; then
        for abi in arm64-v8a armeabi-v7a x86 x86_64; do
            build_for_abi "$abi"
            verify_installation "$abi"
        done
    else
        build_for_abi "$TARGET_ABI"
        verify_installation "$TARGET_ABI"
    fi

    # Create summary
    create_summary
}

# Run main function
main "$@"
