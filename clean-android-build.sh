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
echo "  ./build-libusb-android.sh all"
echo "  ./build-opensc-android.sh all"
