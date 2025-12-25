# Building OpenSSL for Android

Complete guide for cross-compiling OpenSSL for Android to enable full cryptographic functionality in OpenSC.

## Overview

OpenSSL provides cryptographic functionality for OpenSC. While OpenSC can build without OpenSSL, having it enables:
- Full cryptographic operations
- RSA, ECDSA, and other algorithms
- Certificate handling and validation
- Secure communication protocols
- Enhanced smart card operations

## Quick Start

```bash
# 1. Set NDK path (if not already set)
export ANDROID_NDK_ROOT=/path/to/android-ndk

# 2. Build OpenSSL for all Android architectures
./build-openssl-android.sh all

# 3. Build OpenSC with OpenSSL support
./build-opensc-android.sh all
```

The OpenSC build script will automatically detect and use the compiled OpenSSL libraries.

## Single Architecture Build

For faster builds or testing:

```bash
# Build for 64-bit ARM (most common)
./build-openssl-android.sh arm64-v8a
```

**Available architectures:**
- `arm64-v8a` - Modern 64-bit ARM devices
- `armeabi-v7a` - Older 32-bit ARM devices
- `x86_64` - 64-bit emulators
- `x86` - 32-bit emulators

## What Gets Built

### Libraries
- **libcrypto.so** - Core cryptographic library
- **libssl.so** - SSL/TLS implementation
- **libcrypto.a** - Static crypto library (for reference)
- **libssl.a** - Static SSL library (for reference)

### Headers
Complete OpenSSL header files in `include/openssl/`

### Configuration Files
- pkg-config files for easy integration
- OpenSSL configuration in `ssl/` directory

## Build Output Structure

```
build-android/
├── openssl-3.3.0.tar.gz              # Downloaded source
├── openssl-build-[ABI]/              # Build directory per ABI
└── openssl-install/                  # Installation directory
    └── [ABI]/
        ├── lib/
        │   ├── libcrypto.so          # ~3-4 MB
        │   ├── libssl.so             # ~500 KB
        │   ├── libcrypto.a           # Static (optional)
        │   ├── libssl.a              # Static (optional)
        │   └── pkgconfig/
        │       ├── openssl.pc
        │       ├── libcrypto.pc
        │       └── libssl.pc
        ├── include/
        │   └── openssl/              # All header files
        └── ssl/
            └── openssl.cnf           # OpenSSL configuration
```

## Configuration Details

### OpenSSL Version
- **Current:** 3.3.0
- **Minimum:** 3.0.x
- To change version, edit `OPENSSL_VERSION` in the script

### Build Configuration
The script configures OpenSSL with:
- `android-arm64` / `android-arm` / `android-x86_64` / `android-x86` targets
- API level 21 (Android 5.0+)
- Shared library build enabled
- Tests disabled (not needed for cross-compilation)
- Console UI disabled (not available on Android)
- Position Independent Code (PIC) enabled

### Compiler Flags
- `-D__ANDROID_API__=21` - Target API level
- `-fPIC` - Position independent code
- Optimizations enabled by default

## Integration with OpenSC

### Automatic Integration

The `build-opensc-android.sh` script automatically:
1. Detects OpenSSL in `build-android/openssl-install/[ABI]/`
2. Adds OpenSSL include and library paths
3. Enables OpenSSL support in OpenSC
4. Links against libcrypto and libssl

No manual configuration needed!

### Manual Integration

If building OpenSC manually:

```bash
export PKG_CONFIG_PATH="build-android/openssl-install/arm64-v8a/lib/pkgconfig"
export CFLAGS="-I$PWD/build-android/openssl-install/arm64-v8a/include"
export LDFLAGS="-L$PWD/build-android/openssl-install/arm64-v8a/lib"

./configure --enable-openssl ...
```

## Using in Android Apps

### 1. Copy Libraries to Your App

```bash
# Copy for arm64-v8a
cp build-android/openssl-install/arm64-v8a/lib/libcrypto.so \
   your-app/src/main/jniLibs/arm64-v8a/

cp build-android/openssl-install/arm64-v8a/lib/libssl.so \
   your-app/src/main/jniLibs/arm64-v8a/
```

### 2. Load Libraries in Order

In your Java/Kotlin code:

```kotlin
class OpenSCWrapper {
    companion object {
        init {
            // Load OpenSSL libraries BEFORE OpenSC
            System.loadLibrary("crypto")
            System.loadLibrary("ssl")
            System.loadLibrary("opensc")  // or other OpenSC libraries
        }
    }
}
```

**Important:** Load `crypto` and `ssl` before any library that depends on them.

### 3. File Structure

```
app/src/main/
└── jniLibs/
    ├── arm64-v8a/
    │   ├── libcrypto.so       # ~3-4 MB
    │   ├── libssl.so          # ~500 KB
    │   └── libopensc.so       # ~1 MB
    ├── armeabi-v7a/
    │   └── ...
    └── x86_64/
        └── ...
```

## Verification

After building, verify the installation:

```bash
# Check libraries
ls -lh build-android/openssl-install/arm64-v8a/lib/lib*.so

# Check headers
ls build-android/openssl-install/arm64-v8a/include/openssl/ | head

# Check pkg-config
cat build-android/openssl-install/arm64-v8a/lib/pkgconfig/openssl.pc

# Check symbols
nm -D build-android/openssl-install/arm64-v8a/lib/libcrypto.so | grep -i "rsa_new"
```

## Library Sizes

Approximate sizes after building:

| Library | Size (arm64-v8a) | Purpose |
|---------|------------------|---------|
| libcrypto.so | ~3-4 MB | Cryptographic algorithms |
| libssl.so | ~500 KB | SSL/TLS implementation |
| **Total** | **~4 MB** | Per architecture |

For all 4 architectures: ~16 MB total

**Size optimization:** Consider using only required architectures (arm64-v8a + armeabi-v7a = ~8 MB)

## Troubleshooting

### Build Errors

**"ANDROID_NDK_ROOT is not set"**
```bash
export ANDROID_NDK_ROOT=/path/to/ndk
```

**"Configure failed"**
- Check NDK version (need r21+)
- Verify toolchain exists in NDK
- Check write permissions in build directory

**"make: command not found"**
```bash
# macOS
brew install make

# Linux
sudo apt-get install build-essential
```

### OpenSSL Not Detected by OpenSC

If `build-opensc-android.sh` doesn't detect OpenSSL:

1. Check OpenSSL installation:
   ```bash
   ls build-android/openssl-install/arm64-v8a/lib/libcrypto.so
   ```

2. Verify pkg-config file exists:
   ```bash
   cat build-android/openssl-install/arm64-v8a/lib/pkgconfig/libcrypto.pc
   ```

3. Check OpenSC build output for OpenSSL detection message

### Runtime Issues in Android App

**"dlopen failed: library not found"**
- Ensure libcrypto.so and libssl.so are in jniLibs/[ABI]/
- Load crypto and ssl before opensc
- Check ABI matches device architecture

**"symbol not found"**
- Rebuild with same NDK version
- Ensure all libraries use same API level
- Verify library loading order

## Advanced Configuration

### Custom OpenSSL Version

Edit `build-openssl-android.sh`:

```bash
OPENSSL_VERSION="3.2.1"  # Change to desired version
OPENSSL_URL="https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz"
```

Supported versions: OpenSSL 3.0.x and 3.x.x

### Custom API Level

To target a different Android version:

```bash
# In build-openssl-android.sh
API_LEVEL=23  # Android 6.0
```

**Recommendation:** Keep API 21 for maximum compatibility.

### Build Flags Customization

Edit the Configure command in the script:

```bash
./Configure ${OPENSSL_TARGET} \
    -D__ANDROID_API__=${API_LEVEL} \
    --prefix="${ABI_INSTALL_DIR}" \
    no-tests \
    no-ui-console \
    enable-ec_nistp_64_gcc_128 \  # Add optimizations
    shared \
    -fPIC
```

### Static Linking

If you prefer static linking (larger binaries, no runtime dependency):

```bash
# Modify Configure in script:
./Configure ${OPENSSL_TARGET} \
    ... \
    no-shared \
    -fPIC
```

Then use `.a` files instead of `.so` files.

## Performance Considerations

### Build Time
- Per architecture: ~10-15 minutes
- All architectures: ~40-60 minutes
- Single architecture (arm64-v8a): ~10 minutes

### Runtime Performance
OpenSSL 3.x includes:
- Hardware acceleration support
- ARM NEON optimizations (when available)
- Optimized assembly for cryptographic operations

## Security Considerations

### Version Selection
- **Recommended:** Latest 3.x.x stable release
- **Minimum:** OpenSSL 3.0.0
- Always use the latest patch version for security fixes

### Updates
Regularly rebuild with latest OpenSSL version:
```bash
# Update version in script, then:
./clean-android-build.sh -f
./build-openssl-android.sh all
./build-opensc-android.sh all
```

### Verification
Verify OpenSSL build authenticity:
```bash
# Download signature file
curl -O https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz.asc

# Verify (requires OpenSSL team's public key)
gpg --verify openssl-${OPENSSL_VERSION}.tar.gz.asc openssl-${OPENSSL_VERSION}.tar.gz
```

## Clean Build

Remove all OpenSSL build artifacts:

```bash
# Using the cleanup script
./clean-android-build.sh

# Or manually
rm -rf build-android/openssl-*
rm -rf build-android/openssl-install/
```

## Full Build Sequence

For a complete OpenSC + OpenSSL build:

```bash
# 1. Set environment
export ANDROID_NDK_ROOT=/path/to/ndk

# 2. Build dependencies in order
./build-openssl-android.sh all      # ~40-60 minutes
./build-libusb-android.sh all       # ~5-10 minutes
./build-opensc-android.sh all       # ~15-30 minutes

# Total time: ~60-100 minutes for all architectures
```

For faster development builds:

```bash
# Build only arm64-v8a
./build-openssl-android.sh arm64-v8a    # ~10 minutes
./build-libusb-android.sh arm64-v8a     # ~2 minutes
./build-opensc-android.sh arm64-v8a     # ~5 minutes

# Total time: ~17 minutes for single architecture
```

## Additional Resources

- **OpenSSL Documentation:** https://www.openssl.org/docs/
- **OpenSSL for Android:** https://wiki.openssl.org/index.php/Android
- **Android NDK:** https://developer.android.com/ndk
- **OpenSSL Releases:** https://www.openssl.org/source/

## Common Use Cases

### Development and Testing
```bash
./build-openssl-android.sh arm64-v8a
```
Fast builds for local testing on device/emulator.

### Production Builds
```bash
./build-openssl-android.sh all
```
Build all architectures for app store release.

### CI/CD Integration
```bash
#!/bin/bash
set -e
export ANDROID_NDK_ROOT=/opt/android-ndk
./build-openssl-android.sh all
./build-libusb-android.sh all
./build-opensc-android.sh all
# Copy outputs to artifacts directory
cp -r build-android/opensc-install/* $ARTIFACTS_DIR/
```

## License

OpenSSL is dual-licensed under:
- Apache License 2.0 (OpenSSL 3.x)
- OpenSSL License + SSLeay License (older versions)

Ensure compliance when distributing Android apps with OpenSSL.

## Support

For OpenSSL-specific issues:
- OpenSSL Mailing Lists: https://www.openssl.org/community/mailinglists.html
- OpenSSL GitHub: https://github.com/openssl/openssl

For integration with OpenSC:
- Check [ANDROID_BUILD.md](ANDROID_BUILD.md)
- OpenSC Issues: https://github.com/OpenSC/OpenSC/issues

---

**Next Steps:**
1. Build OpenSSL with this script
2. Build libusb: `./build-libusb-android.sh`
3. Build OpenSC: `./build-opensc-android.sh`
4. Integrate into your Android app
