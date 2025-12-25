#!/bin/bash
#
# Build script for OpenSC PDF Signer (Desktop)
#

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DESKTOP_DIR="${SCRIPT_DIR}/desktop"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}  OpenSC PDF Signer - Desktop Build${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    echo "Checking prerequisites..."

    if ! command -v java &> /dev/null; then
        print_error "Java not found. Please install JDK 8 or higher."
        exit 1
    fi
    print_success "Java found: $(java -version 2>&1 | head -n 1)"

    if ! command -v mvn &> /dev/null; then
        print_error "Maven not found. Please install Maven."
        exit 1
    fi
    print_success "Maven found: $(mvn -version 2>&1 | head -n 1)"

    if ! command -v opensc-tool &> /dev/null; then
        print_error "OpenSC not found. Please install OpenSC."
        exit 1
    fi
    print_success "OpenSC found: $(opensc-tool --version 2>&1 | head -n 1)"

    echo ""
}

# Build with Maven
build_project() {
    echo "Building PDF Signer..."
    cd "${DESKTOP_DIR}"

    if [ "$1" == "clean" ]; then
        print_info "Cleaning previous build..."
        mvn clean
    fi

    print_info "Compiling and packaging..."
    mvn package -q

    if [ $? -eq 0 ]; then
        print_success "Build completed successfully!"
    else
        print_error "Build failed!"
        exit 1
    fi

    echo ""
}

# Show build results
show_results() {
    echo "Build Results:"
    echo "=============="

    JAR_FILE="${DESKTOP_DIR}/target/pkcs11-pdf-signer-1.0.0-jar-with-dependencies.jar"

    if [ -f "$JAR_FILE" ]; then
        SIZE=$(du -h "$JAR_FILE" | cut -f1)
        print_success "Executable JAR: $JAR_FILE ($SIZE)"

        echo ""
        echo "Usage:"
        echo "------"
        echo "java -jar $JAR_FILE \\"
        echo "    <pkcs11-config> <pin> <input.pdf> <output.pdf> [name] [location] [reason]"
        echo ""
        echo "Example:"
        echo "--------"
        echo "java -jar $JAR_FILE \\"
        echo "    ../opensc-pkcs11.cfg 1234 document.pdf signed.pdf \\"
        echo "    \"John Doe\" \"Office\" \"Approval\""
    else
        print_error "JAR file not found!"
    fi

    echo ""
}

# Test OpenSC configuration
test_opensc() {
    echo "Testing OpenSC..."
    echo "=================="

    print_info "Available readers:"
    opensc-tool --list-readers || print_error "Failed to list readers"

    echo ""

    # Try to find PKCS#11 library
    PKCS11_LIB=""

    if [ -f "/usr/local/lib/opensc-pkcs11.so" ]; then
        PKCS11_LIB="/usr/local/lib/opensc-pkcs11.so"
    elif [ -f "/opt/homebrew/lib/opensc-pkcs11.so" ]; then
        PKCS11_LIB="/opt/homebrew/lib/opensc-pkcs11.so"
    elif [ -f "/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so" ]; then
        PKCS11_LIB="/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so"
    fi

    if [ -n "$PKCS11_LIB" ]; then
        print_success "PKCS#11 library found: $PKCS11_LIB"

        CONFIG_FILE="${SCRIPT_DIR}/opensc-pkcs11.cfg"
        if [ -f "$CONFIG_FILE" ]; then
            CURRENT_LIB=$(grep "^library" "$CONFIG_FILE" | cut -d= -f2 | xargs)
            if [ "$CURRENT_LIB" != "$PKCS11_LIB" ]; then
                print_info "Updating config file with correct library path..."
                sed -i.bak "s|^library.*|library = $PKCS11_LIB|" "$CONFIG_FILE"
                print_success "Config updated: $CONFIG_FILE"
            fi
        fi
    else
        print_error "PKCS#11 library not found in common locations"
        print_info "Please update opensc-pkcs11.cfg manually"
    fi

    echo ""
}

# Main execution
main() {
    print_header

    check_prerequisites

    # Check for clean argument
    if [ "$1" == "clean" ]; then
        build_project "clean"
    else
        build_project
    fi

    show_results

    test_opensc

    print_success "All done! Your PDF signer is ready to use."
}

# Run main
main "$@"
