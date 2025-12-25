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
    echo "For detailed integration instructions, see:"
    echo "  - ANDROID_BUILD.md (comprehensive guide)"
    echo "  - ANDROID_QUICK_START.md (quick reference)"
    if [ "$BUILD_OPENSSL" = "yes" ]; then
        echo "  - OPENSSL_ANDROID.md (OpenSSL specific)"
    fi
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
