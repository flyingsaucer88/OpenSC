# OpenSC Android Build - Unified Reference

**Complete guide combining all Android build scripts, configurations, and integration details in one place.**

---

## Table of Contents

1. [Overview](#overview)
2. [Quick Start Commands](#quick-start-commands)
3. [Prerequisites](#prerequisites)
4. [Build Scripts - Usage Guide](#build-scripts---usage-guide)
5. [Complete Script Source Code](#complete-script-source-code)
   - [Master Build Script](#1-master-build-script-build-all-androidsh)
   - [OpenSSL Build Script](#2-openssl-build-script-build-openssl-androidsh)
   - [libusb Build Script](#3-libusb-build-script-build-libusb-androidsh)
   - [OpenSC Build Script](#4-opensc-build-script-build-opensc-androidsh)
   - [Cleanup Script](#5-cleanup-script-clean-android-buildsh)
6. [Native JNI Code](#native-jni-code)
   - [USB Android Bridge](#usb-android-bridge-source)
   - [OpenSC Android Bridge](#opensc-android-bridge-source)
   - [CMake Configuration](#cmake-configuration)
7. [Output Directory Structure](#output-directory-structure)
8. [Android App Integration](#android-app-integration)
9. [Troubleshooting](#troubleshooting)

---

## Overview

This document consolidates all Android build files for the OpenSC project, which enables smart card communication via USB CCID readers on Android devices.

### What Gets Built

| Component | Version | Purpose |
|-----------|---------|---------|
| OpenSSL | 3.3.0 | Cryptographic library (optional but recommended) |
| libusb | 1.0.27 | Low-level USB communication |
| OpenSC | Current | Smart card middleware with PKCS#11/PKCS#15 |

### Supported Architectures

| ABI | Description | Use Case |
|-----|-------------|----------|
| `arm64-v8a` | 64-bit ARM | Modern Android phones (2018+) |
| `armeabi-v7a` | 32-bit ARM | Older Android devices |
| `x86_64` | 64-bit x86 | Android emulators |
| `x86` | 32-bit x86 | Older emulators |

### What's Enabled/Disabled

**Enabled:**
- Direct USB Communication via libusb
- CCID Protocol for smart card readers
- USB OTG Support
- PKCS#11 and PKCS#15 interfaces
- All OpenSC command-line tools

**Disabled (Not available on Android):**
- PC/SC (replaced by libusb)
- CryptoTokenKit (macOS only)
- CT-API, OpenCT (legacy interfaces)
- Desktop notifications

---

## Quick Start Commands

```bash
# 1. Set Android NDK path
export ANDROID_NDK_ROOT=/path/to/android-ndk

# 2. Option A: Build everything with one command
./build-all-android.sh --with-openssl all

# 2. Option B: Build components individually
./build-openssl-android.sh all    # Optional but recommended
./build-libusb-android.sh all
./build-opensc-android.sh all

# 3. For single architecture (faster)
./build-all-android.sh arm64-v8a

# 4. Clean previous builds
./clean-android-build.sh --force
```

---

## Prerequisites

### Required Software

**Android NDK:**
- Version r21 or later (r25+ recommended)
- Download: https://developer.android.com/ndk/downloads
- Set environment variable: `export ANDROID_NDK_ROOT=/path/to/android-ndk`

**Build Tools:**

```bash
# macOS
brew install autoconf automake libtool pkg-config curl

# Linux (Ubuntu/Debian)
sudo apt-get install autoconf automake libtool pkg-config build-essential curl
```

### Android Device Requirements

- Android 5.0+ (API 21)
- USB OTG hardware support
- USB host permissions in app

---

## Build Scripts - Usage Guide

### Master Build Script (`build-all-android.sh`)

**Purpose:** Orchestrates the complete build process for all components.

```bash
./build-all-android.sh [OPTIONS] [ABI]

OPTIONS:
  --with-openssl     Build with OpenSSL support (default)
  --without-openssl  Build without OpenSSL support
  --clean            Clean build directories before building
  -h, --help         Show help message

ABI:
  arm64-v8a          Build for 64-bit ARM
  armeabi-v7a        Build for 32-bit ARM
  x86_64             Build for 64-bit x86
  x86                Build for 32-bit x86
  all                Build for all architectures (default)
```

**Examples:**
```bash
./build-all-android.sh                          # Build everything with OpenSSL
./build-all-android.sh arm64-v8a                # Build for ARM64 only
./build-all-android.sh --without-openssl all    # Build without OpenSSL
./build-all-android.sh --clean --with-openssl   # Clean build with OpenSSL
```

### Individual Build Scripts

| Script | Purpose | Prerequisites |
|--------|---------|---------------|
| `build-openssl-android.sh [ABI]` | Build OpenSSL 3.3.0 | NDK only |
| `build-libusb-android.sh [ABI]` | Build libusb 1.0.27 | NDK only |
| `build-opensc-android.sh [ABI]` | Build OpenSC | libusb (OpenSSL optional) |
| `clean-android-build.sh [-f]` | Remove build artifacts | None |

---

## Complete Script Source Code

### 1. Master Build Script (`build-all-android.sh`)

```bash
#!/bin/bash
#
# Build complete OpenSC stack for Android
# This script builds OpenSSL, libusb, and OpenSC in the correct order
#
# Prerequisites:
# - Android NDK installed
# - Set ANDROID_NDK_ROOT environment variable
#
# Usage: ./build-all-android.sh [OPTIONS] [ABI]
#   OPTIONS:
#     --with-openssl    Build with OpenSSL support (default)
#     --without-openssl Build without OpenSSL support
#     --clean           Clean build directories before building
#
#   ABI: arm64-v8a, armeabi-v7a, x86, x86_64, or "all" (default)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default options
BUILD_OPENSSL="yes"
CLEAN_BUILD="no"
TARGET_ABI="all"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --with-openssl)
            BUILD_OPENSSL="yes"
            shift
            ;;
        --without-openssl)
            BUILD_OPENSSL="no"
            shift
            ;;
        --clean)
            CLEAN_BUILD="yes"
            shift
            ;;
        arm64-v8a|armeabi-v7a|x86|x86_64|all)
            TARGET_ABI="$1"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS] [ABI]"
            echo ""
            echo "OPTIONS:"
            echo "  --with-openssl     Build with OpenSSL support (default)"
            echo "  --without-openssl  Build without OpenSSL support"
            echo "  --clean            Clean build directories before building"
            echo "  -h, --help         Show this help message"
            echo ""
            echo "ABI:"
            echo "  arm64-v8a          Build for 64-bit ARM"
            echo "  armeabi-v7a        Build for 32-bit ARM"
            echo "  x86_64             Build for 64-bit x86"
            echo "  x86                Build for 32-bit x86"
            echo "  all                Build for all architectures (default)"
            echo ""
            echo "Examples:"
            echo "  $0                                 # Build everything with OpenSSL"
            echo "  $0 arm64-v8a                       # Build for ARM64 only"
            echo "  $0 --without-openssl all           # Build without OpenSSL"
            echo "  $0 --clean --with-openssl all      # Clean build with OpenSSL"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Print header
print_header() {
    echo ""
    echo -e "${BLUE}=============================================="
    echo "$1"
    echo -e "==============================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"

    # Check for NDK
    if [ -z "$ANDROID_NDK_ROOT" ]; then
        print_error "ANDROID_NDK_ROOT is not set"
        echo "Please set ANDROID_NDK_ROOT to your Android NDK installation path"
        echo "Example: export ANDROID_NDK_ROOT=/path/to/android-ndk"
        exit 1
    fi

    if [ ! -d "$ANDROID_NDK_ROOT" ]; then
        print_error "ANDROID_NDK_ROOT directory does not exist: $ANDROID_NDK_ROOT"
        exit 1
    fi

    print_success "Android NDK found at: $ANDROID_NDK_ROOT"

    # Check for required build scripts
    local scripts=("build-libusb-android.sh" "build-opensc-android.sh")
    if [ "$BUILD_OPENSSL" = "yes" ]; then
        scripts+=("build-openssl-android.sh")
    fi

    for script in "${scripts[@]}"; do
        if [ ! -f "${SCRIPT_DIR}/${script}" ]; then
            print_error "Required build script not found: ${script}"
            exit 1
        fi
        if [ ! -x "${SCRIPT_DIR}/${script}" ]; then
            print_warning "Build script not executable: ${script}, making it executable..."
            chmod +x "${SCRIPT_DIR}/${script}"
        fi
    done

    print_success "All build scripts found"

    # Check for required tools
    local tools=("curl" "tar" "make")
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            print_error "Required tool not found: $tool"
            exit 1
        fi
    done

    print_success "All required tools found"
    echo ""
}

# Clean build directories
clean_build_dirs() {
    if [ "$CLEAN_BUILD" = "yes" ]; then
        print_header "Cleaning Build Directories"

        if [ -x "${SCRIPT_DIR}/clean-android-build.sh" ]; then
            "${SCRIPT_DIR}/clean-android-build.sh" --force
        else
            print_warning "Clean script not found, removing build directory manually"
            rm -rf "${SCRIPT_DIR}/build-android"
        fi

        print_success "Build directories cleaned"
        echo ""
    fi
}

# Build OpenSSL
build_openssl() {
    if [ "$BUILD_OPENSSL" = "yes" ]; then
        print_header "Building OpenSSL for ${TARGET_ABI}"

        local start_time=$(date +%s)

        if "${SCRIPT_DIR}/build-openssl-android.sh" "${TARGET_ABI}"; then
            local end_time=$(date +%s)
            local elapsed=$((end_time - start_time))
            print_success "OpenSSL build completed in ${elapsed} seconds"
        else
            print_error "OpenSSL build failed"
            exit 1
        fi

        echo ""
    else
        print_warning "Skipping OpenSSL build (building without OpenSSL support)"
        echo ""
    fi
}

# Build libusb
build_libusb() {
    print_header "Building libusb for ${TARGET_ABI}"

    local start_time=$(date +%s)

    if "${SCRIPT_DIR}/build-libusb-android.sh" "${TARGET_ABI}"; then
        local end_time=$(date +%s)
        local elapsed=$((end_time - start_time))
        print_success "libusb build completed in ${elapsed} seconds"
    else
        print_error "libusb build failed"
        exit 1
    fi

    echo ""
}

# Build OpenSC
build_opensc() {
    print_header "Building OpenSC for ${TARGET_ABI}"

    local start_time=$(date +%s)

    if "${SCRIPT_DIR}/build-opensc-android.sh" "${TARGET_ABI}"; then
        local end_time=$(date +%s)
        local elapsed=$((end_time - start_time))
        print_success "OpenSC build completed in ${elapsed} seconds"
    else
        print_error "OpenSC build failed"
        exit 1
    fi

    echo ""
}

# Print build summary
print_summary() {
    print_header "Build Summary"

    local build_dir="${SCRIPT_DIR}/build-android"

    echo "Build configuration:"
    echo "  Target ABI:      ${TARGET_ABI}"
    echo "  OpenSSL:         ${BUILD_OPENSSL}"
    echo "  Clean build:     ${CLEAN_BUILD}"
    echo ""

    echo "Build outputs:"

    if [ "$BUILD_OPENSSL" = "yes" ]; then
        if [ -d "${build_dir}/openssl-install" ]; then
            echo "  OpenSSL:         ${build_dir}/openssl-install/"
            for abi_dir in "${build_dir}/openssl-install"/*; do
                if [ -d "$abi_dir" ]; then
                    local abi=$(basename "$abi_dir")
                    if [ -f "${abi_dir}/lib/libcrypto.so" ]; then
                        echo "    ✓ ${abi}"
                    fi
                fi
            done
        fi
    fi

    if [ -d "${build_dir}/install" ]; then
        echo "  libusb:          ${build_dir}/install/"
        for abi_dir in "${build_dir}/install"/*; do
            if [ -d "$abi_dir" ]; then
                local abi=$(basename "$abi_dir")
                if [ -f "${abi_dir}/lib/libusb-1.0.so" ]; then
                    echo "    ✓ ${abi}"
                fi
            fi
        done
    fi

    if [ -d "${build_dir}/opensc-install" ]; then
        echo "  OpenSC:          ${build_dir}/opensc-install/"
        for abi_dir in "${build_dir}/opensc-install"/*; do
            if [ -d "$abi_dir" ]; then
                local abi=$(basename "$abi_dir")
                if [ -f "${abi_dir}/lib/libopensc.so" ]; then
                    echo "    ✓ ${abi}"
                fi
            fi
        done
    fi

    echo ""
    print_success "Build completed successfully!"
    echo ""
    echo "Next steps:"
    echo "  1. Copy libraries to your Android app's jniLibs directory"
    echo "  2. Add USB permissions to AndroidManifest.xml"
    echo "  3. Implement JNI wrapper or use command-line tools"
    echo ""
}

# Main execution
main() {
    local overall_start=$(date +%s)

    print_header "OpenSC Android Build"

    echo "Configuration:"
    echo "  Target ABI:      ${TARGET_ABI}"
    echo "  OpenSSL:         ${BUILD_OPENSSL}"
    echo "  Clean build:     ${CLEAN_BUILD}"
    echo "  NDK:             ${ANDROID_NDK_ROOT}"
    echo ""

    # Run build steps
    check_prerequisites
    clean_build_dirs
    build_openssl
    build_libusb
    build_opensc

    local overall_end=$(date +%s)
    local total_elapsed=$((overall_end - overall_start))

    print_summary

    print_info "Total build time: ${total_elapsed} seconds"
    echo ""
}

# Run main function
main
```

---

### 2. OpenSSL Build Script (`build-openssl-android.sh`)

```bash
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
```

---

### 3. libusb Build Script (`build-libusb-android.sh`)

```bash
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
```

---

### 4. OpenSC Build Script (`build-opensc-android.sh`)

```bash
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
        --disable-strict \
        --disable-pedantic \
        ${OPENSSL_CONFIGURE_FLAGS} \
        --with-completiondir="${ABI_INSTALL_DIR}/etc/bash_completion.d" \
        LIBUSB_CFLAGS="-I${LIBUSB_ABI_PREFIX}/include/libusb-1.0" \
        LIBUSB_LIBS="-L${LIBUSB_ABI_PREFIX}/lib -lusb-1.0"

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
```

---

### 5. Cleanup Script (`clean-android-build.sh`)

```bash
#!/bin/bash
#
# Clean Android build artifacts
# Use this script to remove all Android build files and start fresh
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build-android"

echo "OpenSC Android Build Cleanup"
echo "============================="
echo ""

if [ ! -d "$BUILD_DIR" ]; then
    echo "No build directory found at: $BUILD_DIR"
    echo "Nothing to clean."
    exit 0
fi

echo "This will remove the following:"
echo "  - All downloaded source archives"
echo "  - All extracted source directories"
echo "  - All build artifacts"
echo "  - All compiled libraries (libusb and OpenSC)"
echo ""
echo "Directory to be removed: $BUILD_DIR"
echo ""

# Check for --force flag
if [ "$1" != "--force" ] && [ "$1" != "-f" ]; then
    read -p "Are you sure you want to proceed? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cleanup cancelled."
        exit 0
    fi
fi

echo ""
echo "Cleaning up..."

# Remove the entire build directory
rm -rf "$BUILD_DIR"

echo "✓ Build directory removed"
echo ""
echo "Cleanup complete!"
echo ""
echo "To rebuild, run:"
echo "  ./build-openssl-android.sh all    # Optional"
echo "  ./build-libusb-android.sh all"
echo "  ./build-opensc-android.sh all"
```

---

## Native JNI Code

### USB Android Bridge Source

**File: `android/usb_android.c`**

```c
/*
 * Android USB Host API integration layer for libusb/OpenSC
 *
 * This file provides a bridge between Android's USB host API and libusb,
 * allowing OpenSC to access USB CCID smart card readers on Android.
 *
 * Copyright (C) 2024 OpenSC Project
 * Licensed under LGPL 2.1+
 */

#include <jni.h>
#include <android/log.h>
#include <libusb-1.0/libusb.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>

#define LOG_TAG "OpenSC-USB"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

/* Global USB context */
static libusb_context *usb_context = NULL;
static JavaVM *cached_jvm = NULL;

/* USB device info structure */
typedef struct {
    int fd;
    char device_name[256];
    uint16_t vendor_id;
    uint16_t product_id;
    uint8_t bus_number;
    uint8_t device_address;
} android_usb_device_t;

/*
 * Initialize libusb with Android-specific settings
 */
JNIEXPORT jint JNICALL
Java_org_opensc_android_UsbManager_initializeLibusb(JNIEnv *env, jobject obj)
{
    int rc;

    LOGI("Initializing libusb for Android");

    if (usb_context != NULL) {
        LOGW("libusb already initialized");
        return 0;
    }

    rc = libusb_init(&usb_context);
    if (rc < 0) {
        LOGE("Failed to initialize libusb: %s", libusb_error_name(rc));
        return rc;
    }

    /* Set debug level for development */
    libusb_set_option(usb_context, LIBUSB_OPTION_LOG_LEVEL, LIBUSB_LOG_LEVEL_INFO);

    /* Cache JVM for callbacks */
    (*env)->GetJavaVM(env, &cached_jvm);

    LOGI("libusb initialized successfully");
    return 0;
}

/*
 * Cleanup libusb
 */
JNIEXPORT void JNICALL
Java_org_opensc_android_UsbManager_cleanupLibusb(JNIEnv *env, jobject obj)
{
    LOGI("Cleaning up libusb");

    if (usb_context != NULL) {
        libusb_exit(usb_context);
        usb_context = NULL;
    }

    cached_jvm = NULL;
    LOGI("libusb cleaned up");
}

/*
 * Open Android USB device and wrap it for libusb
 */
JNIEXPORT jlong JNICALL
Java_org_opensc_android_UsbManager_openDevice(JNIEnv *env, jobject obj,
                                               jint fd, jint vendorId,
                                               jint productId, jstring deviceName)
{
    android_usb_device_t *device;
    const char *name_str;

    LOGI("Opening USB device: fd=%d, vid=0x%04x, pid=0x%04x", fd, vendorId, productId);

    if (usb_context == NULL) {
        LOGE("libusb not initialized");
        return 0;
    }

    /* Allocate device structure */
    device = (android_usb_device_t *)calloc(1, sizeof(android_usb_device_t));
    if (!device) {
        LOGE("Failed to allocate device structure");
        return 0;
    }

    /* Store device information */
    device->fd = fd;
    device->vendor_id = (uint16_t)vendorId;
    device->product_id = (uint16_t)productId;

    /* Copy device name */
    name_str = (*env)->GetStringUTFChars(env, deviceName, NULL);
    if (name_str) {
        strncpy(device->device_name, name_str, sizeof(device->device_name) - 1);
        (*env)->ReleaseStringUTFChars(env, deviceName, name_str);
    }

    LOGI("Device opened successfully: %s", device->device_name);
    return (jlong)(uintptr_t)device;
}

/*
 * Close Android USB device
 */
JNIEXPORT void JNICALL
Java_org_opensc_android_UsbManager_closeDevice(JNIEnv *env, jobject obj, jlong deviceHandle)
{
    android_usb_device_t *device = (android_usb_device_t *)(uintptr_t)deviceHandle;

    if (!device) {
        LOGW("Attempted to close NULL device");
        return;
    }

    LOGI("Closing USB device: %s", device->device_name);

    /* Close file descriptor if still open */
    if (device->fd >= 0) {
        close(device->fd);
        device->fd = -1;
    }

    free(device);
    LOGI("Device closed");
}

/*
 * Check if device is a CCID smart card reader
 * Returns true if the device has the CCID interface class (0x0B)
 */
JNIEXPORT jboolean JNICALL
Java_org_opensc_android_UsbManager_isCCIDDevice(JNIEnv *env, jobject obj,
                                                 jint vendorId, jint productId)
{
    libusb_device **devs;
    libusb_device *dev = NULL;
    ssize_t cnt;
    int i, j, k;
    jboolean is_ccid = JNI_FALSE;
    struct libusb_device_descriptor desc;

    LOGD("Checking if device is CCID: vid=0x%04x, pid=0x%04x", vendorId, productId);

    if (usb_context == NULL) {
        LOGE("libusb not initialized");
        return JNI_FALSE;
    }

    cnt = libusb_get_device_list(usb_context, &devs);
    if (cnt < 0) {
        LOGE("Failed to get device list: %s", libusb_error_name(cnt));
        return JNI_FALSE;
    }

    /* Find matching device */
    for (i = 0; i < cnt; i++) {
        if (libusb_get_device_descriptor(devs[i], &desc) < 0)
            continue;

        if (desc.idVendor == vendorId && desc.idProduct == productId) {
            dev = devs[i];
            break;
        }
    }

    if (!dev) {
        LOGD("Device not found in USB device list");
        libusb_free_device_list(devs, 1);
        return JNI_FALSE;
    }

    /* Check device configuration for CCID interface */
    for (i = 0; i < desc.bNumConfigurations; i++) {
        struct libusb_config_descriptor *config;

        if (libusb_get_config_descriptor(dev, i, &config) < 0)
            continue;

        for (j = 0; j < config->bNumInterfaces; j++) {
            const struct libusb_interface *iface = &config->interface[j];

            for (k = 0; k < iface->num_altsetting; k++) {
                const struct libusb_interface_descriptor *altsetting = &iface->altsetting[k];

                /* CCID interface class is 0x0B (Chip/Smart Card) */
                if (altsetting->bInterfaceClass == 0x0B) {
                    LOGI("Device is CCID: vid=0x%04x, pid=0x%04x", vendorId, productId);
                    is_ccid = JNI_TRUE;
                    libusb_free_config_descriptor(config);
                    goto cleanup;
                }
            }
        }

        libusb_free_config_descriptor(config);
    }

cleanup:
    libusb_free_device_list(devs, 1);
    return is_ccid;
}
```

---

### OpenSC Android Bridge Source

**File: `android/opensc_android.c`**

```c
/*
 * OpenSC JNI wrapper for Android
 *
 * Provides JNI interface to OpenSC functionality for Android apps
 *
 * Copyright (C) 2024 OpenSC Project
 * Licensed under LGPL 2.1+
 */

#include <jni.h>
#include <android/log.h>
#include <libopensc/opensc.h>
#include <libopensc/cardctl.h>
#include <libopensc/pkcs15.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define LOG_TAG "OpenSC-JNI"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

/* Global OpenSC context */
static sc_context_t *ctx = NULL;
static sc_reader_t **readers = NULL;
static unsigned int reader_count = 0;

/*
 * Initialize OpenSC library
 */
JNIEXPORT jint JNICALL
Java_org_opensc_android_OpenSCBridge_initializeOpenSC(JNIEnv *env, jobject obj)
{
    int rc;

    LOGI("Initializing OpenSC");

    if (ctx != NULL) {
        LOGW("OpenSC already initialized");
        return 0;
    }

    /* Establish OpenSC context */
    rc = sc_establish_context(&ctx, "OpenSC-Android");
    if (rc != SC_SUCCESS) {
        LOGE("Failed to establish context: %s", sc_strerror(rc));
        return rc;
    }

    /* Set up debug level */
    ctx->debug = 2; /* INFO level */

    /* Detect readers */
    reader_count = sc_ctx_get_reader_count(ctx);
    LOGI("Found %u readers", reader_count);

    if (reader_count > 0) {
        readers = (sc_reader_t **)calloc(reader_count, sizeof(sc_reader_t *));
        if (!readers) {
            LOGE("Failed to allocate reader array");
            sc_release_context(ctx);
            ctx = NULL;
            return SC_ERROR_OUT_OF_MEMORY;
        }

        for (unsigned int i = 0; i < reader_count; i++) {
            readers[i] = sc_ctx_get_reader(ctx, i);
            if (readers[i]) {
                LOGI("Reader %u: %s", i, readers[i]->name);
            }
        }
    }

    LOGI("OpenSC initialized successfully");
    return 0;
}

/*
 * Cleanup OpenSC library
 */
JNIEXPORT void JNICALL
Java_org_opensc_android_OpenSCBridge_cleanupOpenSC(JNIEnv *env, jobject obj)
{
    LOGI("Cleaning up OpenSC");

    if (readers) {
        free(readers);
        readers = NULL;
    }
    reader_count = 0;

    if (ctx) {
        sc_release_context(ctx);
        ctx = NULL;
    }

    LOGI("OpenSC cleaned up");
}

/*
 * List smart card readers
 */
JNIEXPORT jobjectArray JNICALL
Java_org_opensc_android_OpenSCBridge_listReaders(JNIEnv *env, jobject obj)
{
    jobjectArray result = NULL;
    jclass stringClass;
    unsigned int i;

    LOGD("Listing readers");

    if (!ctx) {
        LOGE("OpenSC not initialized");
        return NULL;
    }

    /* Refresh reader list */
    reader_count = sc_ctx_get_reader_count(ctx);
    LOGD("Found %u readers", reader_count);

    if (reader_count == 0) {
        /* Return empty array */
        stringClass = (*env)->FindClass(env, "java/lang/String");
        return (*env)->NewObjectArray(env, 0, stringClass, NULL);
    }

    /* Create string array */
    stringClass = (*env)->FindClass(env, "java/lang/String");
    if (!stringClass) {
        LOGE("Failed to find String class");
        return NULL;
    }

    result = (*env)->NewObjectArray(env, reader_count, stringClass, NULL);
    if (!result) {
        LOGE("Failed to create result array");
        return NULL;
    }

    /* Fill array with reader names */
    for (i = 0; i < reader_count; i++) {
        sc_reader_t *reader = sc_ctx_get_reader(ctx, i);
        if (reader && reader->name) {
            jstring readerName = (*env)->NewStringUTF(env, reader->name);
            if (readerName) {
                (*env)->SetObjectArrayElement(env, result, i, readerName);
                (*env)->DeleteLocalRef(env, readerName);
            }
        }
    }

    return result;
}

/*
 * Check if card is present in reader
 */
JNIEXPORT jboolean JNICALL
Java_org_opensc_android_OpenSCBridge_isCardPresent(JNIEnv *env, jobject obj, jint readerIndex)
{
    sc_reader_t *reader;
    unsigned int flags;
    int rc;

    LOGD("Checking card presence in reader %d", readerIndex);

    if (!ctx) {
        LOGE("OpenSC not initialized");
        return JNI_FALSE;
    }

    if (readerIndex < 0 || (unsigned int)readerIndex >= reader_count) {
        LOGE("Invalid reader index: %d", readerIndex);
        return JNI_FALSE;
    }

    reader = sc_ctx_get_reader(ctx, (unsigned int)readerIndex);
    if (!reader) {
        LOGE("Failed to get reader %d", readerIndex);
        return JNI_FALSE;
    }

    /* Detect card */
    rc = sc_detect_card_presence(reader);
    if (rc < 0) {
        LOGE("Failed to detect card: %s", sc_strerror(rc));
        return JNI_FALSE;
    }

    flags = sc_reader_get_state(reader);
    LOGD("Reader flags: 0x%x", flags);

    return (flags & SC_READER_CARD_PRESENT) ? JNI_TRUE : JNI_FALSE;
}

/*
 * Get card ATR (Answer To Reset)
 */
JNIEXPORT jstring JNICALL
Java_org_opensc_android_OpenSCBridge_getCardATR(JNIEnv *env, jobject obj, jint readerIndex)
{
    sc_reader_t *reader;
    sc_card_t *card = NULL;
    char atr_str[SC_MAX_ATR_SIZE * 3];
    jstring result = NULL;
    int rc;
    unsigned int i;

    LOGD("Getting ATR from reader %d", readerIndex);

    if (!ctx) {
        LOGE("OpenSC not initialized");
        return NULL;
    }

    if (readerIndex < 0 || (unsigned int)readerIndex >= reader_count) {
        LOGE("Invalid reader index: %d", readerIndex);
        return NULL;
    }

    reader = sc_ctx_get_reader(ctx, (unsigned int)readerIndex);
    if (!reader) {
        LOGE("Failed to get reader %d", readerIndex);
        return NULL;
    }

    /* Connect to card */
    rc = sc_connect_card(reader, &card);
    if (rc != SC_SUCCESS) {
        LOGE("Failed to connect to card: %s", sc_strerror(rc));
        return NULL;
    }

    /* Format ATR as hex string */
    atr_str[0] = '\0';
    for (i = 0; i < card->atr.len; i++) {
        char hex[4];
        snprintf(hex, sizeof(hex), "%02X ", card->atr.value[i]);
        strcat(atr_str, hex);
    }

    LOGI("ATR: %s", atr_str);

    result = (*env)->NewStringUTF(env, atr_str);

    sc_disconnect_card(card);
    return result;
}

/*
 * Get card information
 */
JNIEXPORT jstring JNICALL
Java_org_opensc_android_OpenSCBridge_getCardInfo(JNIEnv *env, jobject obj, jint readerIndex)
{
    sc_reader_t *reader;
    sc_card_t *card = NULL;
    char info_str[1024];
    jstring result = NULL;
    int rc;

    LOGD("Getting card info from reader %d", readerIndex);

    if (!ctx) {
        LOGE("OpenSC not initialized");
        return NULL;
    }

    if (readerIndex < 0 || (unsigned int)readerIndex >= reader_count) {
        LOGE("Invalid reader index: %d", readerIndex);
        return NULL;
    }

    reader = sc_ctx_get_reader(ctx, (unsigned int)readerIndex);
    if (!reader) {
        LOGE("Failed to get reader %d", readerIndex);
        return NULL;
    }

    /* Connect to card */
    rc = sc_connect_card(reader, &card);
    if (rc != SC_SUCCESS) {
        LOGE("Failed to connect to card: %s", sc_strerror(rc));
        return NULL;
    }

    /* Build info string */
    snprintf(info_str, sizeof(info_str),
            "Card Type: %s\n"
            "Driver: %s\n"
            "ATR Length: %zu bytes\n"
            "Max Send: %zu bytes\n"
            "Max Recv: %zu bytes",
            card->name ? card->name : "Unknown",
            card->driver ? card->driver->name : "Unknown",
            card->atr.len,
            card->max_send_size,
            card->max_recv_size);

    LOGI("Card info: %s", info_str);

    result = (*env)->NewStringUTF(env, info_str);

    sc_disconnect_card(card);
    return result;
}

/*
 * PKCS#15 PIN verification
 */
JNIEXPORT jboolean JNICALL
Java_org_opensc_android_OpenSCBridge_verifyPIN(JNIEnv *env, jobject obj,
                                                jint readerIndex, jstring pin)
{
    sc_reader_t *reader;
    sc_card_t *card = NULL;
    sc_pkcs15_card_t *p15card = NULL;
    sc_pkcs15_object_t *pin_obj = NULL;
    sc_pkcs15_auth_info_t *pin_info;
    const char *pin_str;
    int rc;
    jboolean result = JNI_FALSE;

    if (!ctx || !pin) {
        return JNI_FALSE;
    }

    if (readerIndex < 0 || (unsigned int)readerIndex >= reader_count) {
        LOGE("Invalid reader index: %d", readerIndex);
        return JNI_FALSE;
    }

    reader = sc_ctx_get_reader(ctx, (unsigned int)readerIndex);
    if (!reader) {
        return JNI_FALSE;
    }

    /* Connect to card */
    rc = sc_connect_card(reader, &card);
    if (rc != SC_SUCCESS) {
        LOGE("Failed to connect to card: %s", sc_strerror(rc));
        return JNI_FALSE;
    }

    /* Bind PKCS#15 */
    rc = sc_pkcs15_bind(card, NULL, &p15card);
    if (rc != SC_SUCCESS) {
        LOGE("Failed to bind PKCS#15: %s", sc_strerror(rc));
        sc_disconnect_card(card);
        return JNI_FALSE;
    }

    /* Find first PIN */
    rc = sc_pkcs15_find_pin_by_auth_id(p15card, NULL, &pin_obj);
    if (rc != SC_SUCCESS) {
        LOGE("Failed to find PIN: %s", sc_strerror(rc));
        goto cleanup;
    }

    pin_info = (sc_pkcs15_auth_info_t *)pin_obj->data;
    pin_str = (*env)->GetStringUTFChars(env, pin, NULL);

    /* Verify PIN */
    rc = sc_pkcs15_verify_pin(p15card, pin_obj, (const u8 *)pin_str, strlen(pin_str));

    (*env)->ReleaseStringUTFChars(env, pin, pin_str);

    if (rc == SC_SUCCESS) {
        LOGI("PIN verified successfully");
        result = JNI_TRUE;
    } else {
        LOGE("PIN verification failed: %s", sc_strerror(rc));
    }

cleanup:
    if (p15card) {
        sc_pkcs15_unbind(p15card);
    }
    sc_disconnect_card(card);

    return result;
}
```

---

### CMake Configuration

**File: `android/CMakeLists.txt`**

```cmake
# CMakeLists.txt for OpenSC Android USB integration layer
#
# This builds the JNI bridge libraries for OpenSC on Android using CMake

cmake_minimum_required(VERSION 3.10)
project(opensc-android)

# Android API level
set(ANDROID_API_LEVEL 21)

# Build directories - adjust based on ABI
if(NOT DEFINED ANDROID_ABI)
    set(ANDROID_ABI "arm64-v8a")
endif()

set(BUILD_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../build-android")
set(OPENSC_DIR "${BUILD_ROOT}/opensc-install/${ANDROID_ABI}")
set(LIBUSB_DIR "${BUILD_ROOT}/install/${ANDROID_ABI}")
set(OPENSSL_DIR "${BUILD_ROOT}/openssl-install/${ANDROID_ABI}")

# Find Android log library
find_library(log-lib log)
find_library(android-lib android)

#================================================================
# USB Android Bridge Library
#================================================================
add_library(usb-android SHARED
    usb_android.c
)

target_include_directories(usb-android PRIVATE
    ${LIBUSB_DIR}/include/libusb-1.0
)

target_link_libraries(usb-android
    ${LIBUSB_DIR}/lib/libusb-1.0.so
    ${log-lib}
    ${android-lib}
)

#================================================================
# OpenSC Android Bridge Library
#================================================================
add_library(opensc-android SHARED
    opensc_android.c
)

target_include_directories(opensc-android PRIVATE
    ${OPENSC_DIR}/include
    ${OPENSSL_DIR}/include
    ${LIBUSB_DIR}/include/libusb-1.0
)

target_link_libraries(opensc-android
    ${OPENSC_DIR}/lib/libopensc.so
    ${OPENSSL_DIR}/lib/libcrypto.so
    ${OPENSSL_DIR}/lib/libssl.so
    ${LIBUSB_DIR}/lib/libusb-1.0.so
    ${log-lib}
)

#================================================================
# Installation
#================================================================
install(TARGETS usb-android opensc-android
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)

# Install additional required libraries
install(FILES
    ${LIBUSB_DIR}/lib/libusb-1.0.so
    ${OPENSSL_DIR}/lib/libcrypto.so
    ${OPENSSL_DIR}/lib/libssl.so
    ${OPENSC_DIR}/lib/libopensc.so
    ${OPENSC_DIR}/lib/opensc-pkcs11.so
    DESTINATION ${CMAKE_INSTALL_LIBDIR}
    OPTIONAL
)
```

---

## Output Directory Structure

After a complete build with all architectures:

```
build-android/
├── openssl-3.3.0/                    # OpenSSL source
├── openssl-3.3.0.tar.gz
├── openssl-build-[ABI]/              # OpenSSL build dirs
├── openssl-install/                  # OpenSSL installation
│   └── [ABI]/lib/, include/, ssl/
│
├── libusb-1.0.27/                    # libusb source
│   └── build-[ABI]/
├── libusb-1.0.27.tar.bz2
├── install/                          # libusb installation
│   └── [ABI]/lib/, include/
│
├── opensc-build-[ABI]/               # OpenSC build dirs
└── opensc-install/                   # OpenSC installation
    └── [ABI]/lib/, bin/, etc/
```

---

## Android App Integration

### Step 1: Copy Libraries

```bash
mkdir -p your-app/src/main/jniLibs/{arm64-v8a,armeabi-v7a}

# ARM64
cp build-android/openssl-install/arm64-v8a/lib/libcrypto.so your-app/src/main/jniLibs/arm64-v8a/
cp build-android/openssl-install/arm64-v8a/lib/libssl.so your-app/src/main/jniLibs/arm64-v8a/
cp build-android/install/arm64-v8a/lib/libusb-1.0.so your-app/src/main/jniLibs/arm64-v8a/
cp build-android/opensc-install/arm64-v8a/lib/libopensc.so your-app/src/main/jniLibs/arm64-v8a/
cp build-android/opensc-install/arm64-v8a/lib/opensc-pkcs11.so your-app/src/main/jniLibs/arm64-v8a/
```

### Step 2: AndroidManifest.xml

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-feature android:name="android.hardware.usb.host" />
    <uses-permission android:name="android.hardware.usb.host" />

    <application ...>
        <activity ...>
            <intent-filter>
                <action android:name="android.hardware.usb.action.USB_DEVICE_ATTACHED" />
            </intent-filter>
            <meta-data
                android:name="android.hardware.usb.action.USB_DEVICE_ATTACHED"
                android:resource="@xml/device_filter" />
        </activity>
    </application>
</manifest>
```

### Step 3: USB Device Filter (`res/xml/device_filter.xml`)

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <usb-device class="11" />  <!-- CCID class -->
</resources>
```

### Step 4: Library Loading Order

```java
static {
    System.loadLibrary("crypto");
    System.loadLibrary("ssl");
    System.loadLibrary("usb-1.0");
    System.loadLibrary("opensc");
    System.loadLibrary("usb-android");
}
```

---

## Troubleshooting

### Build Issues

| Error | Solution |
|-------|----------|
| `ANDROID_NDK_ROOT is not set` | `export ANDROID_NDK_ROOT=/path/to/android-ndk` |
| `Toolchain not found` | Install NDK r21+ with LLVM toolchain |
| `libusb not found for [ABI]` | Run `./build-libusb-android.sh [ABI]` first |
| `configure: command not found` | Run `./bootstrap` |

### Runtime Issues

| Issue | Solution |
|-------|----------|
| Library not found | Check jniLibs/[ABI]/ |
| USB permission denied | Check AndroidManifest.xml |
| No readers found | Verify USB OTG and CCID reader |

### Debug Commands

```bash
# Check libraries
file build-android/opensc-install/arm64-v8a/lib/libopensc.so

# Android logcat
adb logcat | grep -E "(OpenSC|libusb)"

# Test on device
adb push build-android/opensc-install/arm64-v8a/bin/opensc-tool /data/local/tmp/
adb shell /data/local/tmp/opensc-tool --list-readers
```

---

## License

- **OpenSC:** LGPL 2.1+
- **libusb:** LGPL 2.1+
- **OpenSSL:** Apache License 2.0

---

*Generated from OpenSC Android build files - January 21, 2026*
