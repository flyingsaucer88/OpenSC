# OpenSC for Android - Complete Guide

Complete cross-compilation setup and integration guide for building OpenSC with USB CCID smart card reader support on Android devices.

**Last Updated:** December 26, 2024

---

## Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Prerequisites](#prerequisites)
4. [Build Process](#build-process)
   - [Building OpenSSL](#building-openssl-for-android)
   - [Building libusb](#building-libusb-for-android)
   - [Building OpenSC](#building-opensc-for-android)
5. [Integration into Android Apps](#integration-into-android-apps)
6. [Architecture](#architecture)
7. [Configuration Details](#configuration-details)
8. [Troubleshooting](#troubleshooting)
9. [Advanced Topics](#advanced-topics)
10. [Resources](#resources)

---

## Overview

This build system enables OpenSC to communicate directly with CCID-compliant USB smart card readers on Android devices through USB OTG (On-The-Go) connections. It achieves this by:

1. **Cross-compiling libusb** for Android to provide low-level USB communication
2. **Building OpenSC** with libusb support instead of PC/SC (which isn't available on Android)
3. **Enabling CCID protocol** over direct USB for smart card operations

### What Was Built

**Cross-Compilation Build System:**
- 5 build scripts supporting all Android ABIs (arm64-v8a, armeabi-v7a, x86_64, x86)
- Automatic dependency detection
- Colored output with progress indicators
- Error handling and validation

**Android USB Host API Integration Layer:**
- Native C/JNI code bridging Android USB API with libusb
- Java wrapper classes for easy integration
- Complete OpenSC operations support
- USB permission and lifecycle management

### Key Features

**Enabled:**
- ✅ Direct USB Communication via libusb (no PC/SC needed)
- ✅ CCID Protocol - Full CCID support for smart card readers
- ✅ USB OTG Support - Works with USB On-The-Go on Android
- ✅ All Card Types - Supports all OpenSC-compatible smart cards
- ✅ PKCS#11 - Complete PKCS#11 interface
- ✅ PKCS#15 - PKCS#15 file system support
- ✅ Command Tools - Full suite of command-line utilities

**Disabled (Not Available on Android):**
- ❌ PC/SC - Not available on Android (replaced by libusb)
- ❌ CryptoTokenKit - macOS only
- ❌ CT-API - Legacy interface
- ❌ OpenCT - Alternative reader interface
- ❌ Desktop Notifications - Not applicable to Android

---

## Quick Start

### TL;DR - Get Building in 5 Minutes

```bash
# 1. Set NDK path
export ANDROID_NDK_ROOT=/path/to/android-ndk

# 2. Build OpenSSL for all Android architectures (optional but recommended)
./build-openssl-android.sh all

# 3. Build libusb for all Android architectures
./build-libusb-android.sh all

# 4. Build OpenSC for all Android architectures
./build-opensc-android.sh all

# 5. Find your compiled libraries
ls build-android/opensc-install/arm64-v8a/lib/
```

**Note:** OpenSSL is optional but highly recommended for full cryptographic functionality.

### What You Get

After successful build, you'll have:

```
build-android/
├── openssl-install/            # OpenSSL libraries (optional)
│   ├── arm64-v8a/
│   │   ├── lib/libcrypto.so    (~3-4 MB)
│   │   ├── lib/libssl.so       (~500 KB)
│   │   └── include/openssl/
│   ├── armeabi-v7a/
│   ├── x86_64/
│   └── x86/
│
├── install/                    # libusb libraries
│   ├── arm64-v8a/
│   │   ├── lib/libusb-1.0.{a,so}
│   │   └── include/libusb-1.0/
│   ├── armeabi-v7a/
│   ├── x86_64/
│   └── x86/
│
└── opensc-install/            # OpenSC libraries and tools
    ├── arm64-v8a/
    │   ├── lib/
    │   │   ├── libopensc.so
    │   │   ├── opensc-pkcs11.so
    │   │   ├── pkcs15init.so
    │   │   └── ...
    │   ├── bin/
    │   │   ├── opensc-tool
    │   │   ├── pkcs11-tool
    │   │   ├── pkcs15-tool
    │   │   └── ...
    │   └── etc/
    │       └── opensc.conf
    ├── armeabi-v7a/
    ├── x86_64/
    └── x86/
```

### Build for Single Architecture

If you only need one architecture (e.g., for testing):

```bash
# Build for 64-bit ARM (most common)
./build-openssl-android.sh arm64-v8a    # Optional but recommended
./build-libusb-android.sh arm64-v8a
./build-opensc-android.sh arm64-v8a
```

**Available architectures:**
- `arm64-v8a` - Modern 64-bit ARM devices
- `armeabi-v7a` - Older 32-bit ARM devices
- `x86_64` - 64-bit emulators
- `x86` - 32-bit emulators

---

## Prerequisites

### Build Environment

**Android NDK:**
- Version r21 or later (r25+ recommended)
- Download: https://developer.android.com/ndk/downloads
- Must set `ANDROID_NDK_ROOT` environment variable

```bash
export ANDROID_NDK_ROOT=/path/to/android-ndk
```

**Build Tools:**
- autoconf
- automake
- libtool
- pkg-config
- make
- curl

**Install on macOS:**
```bash
brew install autoconf automake libtool pkg-config
```

**Install on Linux (Ubuntu/Debian):**
```bash
sudo apt-get install autoconf automake libtool pkg-config build-essential curl
```

### Android Requirements

**Minimum Requirements:**
- Android Version: 5.0 (API 21) or higher
- Hardware: USB OTG support required
- Permissions: USB host mode access

**AndroidManifest.xml:**
```xml
<uses-permission android:name="android.hardware.usb.host" />
<uses-feature android:name="android.hardware.usb.host" />
```

---

## Build Process

### Building OpenSSL for Android

OpenSSL provides cryptographic functionality for OpenSC. While OpenSC can build without OpenSSL, having it enables full cryptographic operations.

#### Quick Start with OpenSSL

```bash
# 1. Set NDK path (if not already set)
export ANDROID_NDK_ROOT=/path/to/android-ndk

# 2. Build OpenSSL for all Android architectures
./build-openssl-android.sh all

# 3. Build OpenSC with OpenSSL support
./build-opensc-android.sh all
```

The OpenSC build script will automatically detect and use the compiled OpenSSL libraries.

#### Single Architecture Build

For faster builds or testing:

```bash
# Build for 64-bit ARM (most common)
./build-openssl-android.sh arm64-v8a
```

#### What Gets Built

**Libraries:**
- `libcrypto.so` - Core cryptographic library (~3-4 MB)
- `libssl.so` - SSL/TLS implementation (~500 KB)
- `libcrypto.a` - Static crypto library (for reference)
- `libssl.a` - Static SSL library (for reference)

**Headers:**
- Complete OpenSSL header files in `include/openssl/`

**Configuration Files:**
- pkg-config files for easy integration
- OpenSSL configuration in `ssl/` directory

#### Build Configuration

**OpenSSL Version:** 3.3.0 (configurable in script)

**Build Options:**
- Target API level 21 (Android 5.0+)
- Shared library build enabled
- Tests disabled (not needed for cross-compilation)
- Console UI disabled (not available on Android)
- Position Independent Code (PIC) enabled

#### Verification

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

#### Library Sizes

Approximate sizes after building:

| Library | Size (arm64-v8a) | Purpose |
|---------|------------------|---------|
| libcrypto.so | ~3-4 MB | Cryptographic algorithms |
| libssl.so | ~500 KB | SSL/TLS implementation |
| **Total** | **~4 MB** | Per architecture |

For all 4 architectures: ~16 MB total

### Building libusb for Android

The `build-libusb-android.sh` script downloads and cross-compiles libusb for all Android architectures.

#### Build Commands

```bash
# Build for all architectures (recommended)
./build-libusb-android.sh all

# Or build for a specific architecture
./build-libusb-android.sh arm64-v8a
```

**Supported architectures:**
- `arm64-v8a` - 64-bit ARM (most modern Android devices)
- `armeabi-v7a` - 32-bit ARM
- `x86_64` - 64-bit x86 (emulators and some tablets)
- `x86` - 32-bit x86 (older emulators)

**Output location:** `build-android/install/[ABI]/`

**What this builds:**
- Static library: `lib/libusb-1.0.a`
- Shared library: `lib/libusb-1.0.so`
- Headers: `include/libusb-1.0/`

#### libusb Configuration

The libusb build uses these configure options:
- `--enable-static` - Build static library
- `--enable-shared` - Build shared library
- `--disable-udev` - Disable udev (not available on Android)
- `--enable-system-log` - Enable Android logcat integration

### Building OpenSC for Android

The `build-opensc-android.sh` script cross-compiles OpenSC with libusb support.

#### Build Commands

```bash
# Build for all architectures (recommended)
./build-opensc-android.sh all

# Or build for a specific architecture
./build-opensc-android.sh arm64-v8a
```

**Requirements:** Must run `build-libusb-android.sh` first (and optionally `build-openssl-android.sh`)

**Output location:** `build-android/opensc-install/[ABI]/`

**What this builds:**
- Shared libraries: `lib/libopensc.so`, `lib/opensc-pkcs11.so`, etc.
- Command-line tools: `bin/opensc-tool`, `bin/pkcs11-tool`, etc.
- Configuration files: `etc/opensc.conf`

#### OpenSC Configuration

The OpenSC build uses these configure options:
- `--disable-pcsc` - Disable PC/SC (not available on Android)
- `--disable-cryptotokenkit` - Disable CryptoTokenKit (macOS only)
- `--disable-ctapi` - Disable CT-API
- `--disable-openct` - Disable OpenCT
- `--disable-notify` - Disable desktop notifications
- `--disable-man` - Skip man page generation
- `--disable-doc` - Skip documentation
- `--disable-tests` - Skip test suite
- `--enable-openssl` - Enable if OpenSSL is available
- `--enable-static` - Build static libraries
- `--enable-shared` - Build shared libraries

#### API Level

Both scripts target **API level 21 (Android 5.0 Lollipop)** which provides:
- Modern USB host API support
- USB OTG functionality
- Sufficient C standard library features

You can modify the `API_LEVEL` variable in the scripts if you need different compatibility.

---

## Integration into Android Apps

### Step 1: Copy Libraries to Your Project

```bash
# For arm64-v8a architecture
cp build-android/openssl-install/arm64-v8a/lib/*.so \
   your-app/src/main/jniLibs/arm64-v8a/

cp build-android/install/arm64-v8a/lib/libusb-1.0.so \
   your-app/src/main/jniLibs/arm64-v8a/

cp build-android/opensc-install/arm64-v8a/lib/*.so \
   your-app/src/main/jniLibs/arm64-v8a/

# Repeat for other architectures as needed
```

### Step 2: Add Permissions

Add to `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.hardware.usb.host" />
<uses-feature android:name="android.hardware.usb.host" />
```

### Step 3: Use OpenSC in Your App

See the [android/README.md](android/README.md) for detailed integration instructions and complete code examples.

#### Basic Usage Example

```java
import org.opensc.android.OpenSCBridge;

public class MainActivity extends Activity {
    private OpenSCBridge opensc;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Initialize OpenSC
        opensc = new OpenSCBridge(this);
        if (!opensc.initialize()) {
            Log.e(TAG, "Failed to initialize");
            return;
        }

        // Find CCID readers
        List<UsbDevice> readers = opensc.getCCIDReaders();

        // Request USB permission (if needed)
        if (!usbManager.hasPermission(device)) {
            usbManager.requestPermission(device, permissionIntent);
        }

        // Open reader
        opensc.openReader(device);

        // Check for card
        if (opensc.isCardPresent(0)) {
            String atr = opensc.getCardATR(0);
            String info = opensc.getCardInfo(0);
            Log.i(TAG, "Card ATR: " + atr);
        }

        // Cleanup
        opensc.cleanup();
    }
}
```

---

## Architecture

### System Stack

```
┌─────────────────────────────────────┐
│     Android Application (Java)      │
├─────────────────────────────────────┤
│   OpenSCBridge.java (Main API)      │ ← High-level interface
├─────────────────────────────────────┤
│   UsbManager.java                   │ ← USB device management
├─────────────────────────────────────┤
│         JNI Bridge Layer            │
├─────────────────────────────────────┤
│  usb_android.c  │ opensc_android.c  │ ← Native integration
├─────────────────┴──────────────────┤
│  libusb-1.0.so  │  libopensc.so    │ ← Core libraries
├─────────────────┴──────────────────┤
│   libcrypto.so  │  libssl.so       │ ← OpenSSL (optional)
├─────────────────────────────────────┤
│      Android USB Host API           │ ← OS interface
├─────────────────────────────────────┤
│         USB OTG Hardware            │
├─────────────────────────────────────┤
│      CCID Smart Card Reader         │ ← Physical device
└─────────────────────────────────────┘
```

### Build Flow

```
1. build-openssl-android.sh
   ↓ (creates libcrypto.so, libssl.so)

2. build-libusb-android.sh
   ↓ (creates libusb-1.0.so)

3. build-opensc-android.sh
   ↓ (creates libopensc.so, opensc-pkcs11.so)

4. Android app build
   ↓ (builds usb-android, opensc-android JNI libraries)

5. Complete APK with all libraries
```

### Architecture Support

| ABI | Description | Priority | Typical Use |
|-----|-------------|----------|-------------|
| arm64-v8a | 64-bit ARM | **High** | Modern Android phones/tablets (2018+) |
| armeabi-v7a | 32-bit ARM | Medium | Older Android devices |
| x86_64 | 64-bit x86 | Low | Android emulators |
| x86 | 32-bit x86 | Low | Older emulators |

**Recommendation:** Build `arm64-v8a` for most modern devices, add `armeabi-v7a` for broader compatibility.

---

## Configuration Details

### libusb Configuration

- API Level: 21 (Android 5.0)
- udev: Disabled (not available on Android)
- System log: Enabled (Android logcat)
- Static library: Enabled
- Shared library: Enabled

### OpenSC Configuration

- API Level: 21 (Android 5.0)
- Reader interface: libusb (direct USB)
- PC/SC: Disabled
- OpenSSL: Auto-detected (optional)
- Static libraries: Enabled
- Shared libraries: Enabled
- Man pages: Disabled (smaller build)
- Tests: Disabled (not needed)

### CCID USB Communication

**How it Works:**

1. **USB OTG Connection**: Smart card reader connects via USB OTG adapter
2. **libusb**: Provides low-level USB communication
3. **OpenSC CCID**: Implements CCID protocol over USB
4. **Card Operations**: Standard smart card operations (PKCS#11, etc.)

### Supported Readers

OpenSC with libusb supports most CCID-compliant smart card readers:
- Generic CCID readers (USB interface class 0x0B)
- ACR122U and similar NFC readers
- Gemalto readers
- Identiv readers
- YubiKey (in CCID mode)

---

## Troubleshooting

### Build Issues

**NDK Not Found**
```bash
Error: ANDROID_NDK_ROOT is not set
```
**Solution:** Set the environment variable:
```bash
export ANDROID_NDK_ROOT=/path/to/android-ndk
```

**Toolchain Not Found**
```bash
Error: Toolchain not found at: ...
```
**Solution:** Ensure you have NDK r21 or later with LLVM toolchain.

**libusb Not Found for OpenSC Build**
```bash
Error: libusb not found for arm64-v8a
```
**Solution:** Build libusb first:
```bash
./build-libusb-android.sh arm64-v8a
```

**OpenSSL Not Found**
```
Warning: OpenSSL not found for arm64-v8a. Building without OpenSSL support.
```
**Solution:** This is not critical. OpenSC will build with limited cryptographic functionality. For full features, build OpenSSL for Android first.

**configure: command not found**
```bash
Solution: Run bootstrap to generate configure script
./bootstrap
```

### Runtime Issues in Android App

**USB Permission Denied in Android App**

**Solution:**
1. Check USB permissions in AndroidManifest.xml
2. Request runtime USB device permission
3. Verify USB OTG support on the device

**Library Not Found**

Ensure all .so files are in jniLibs/[ABI]/ and loaded in correct order:
```java
System.loadLibrary("crypto");
System.loadLibrary("ssl");
System.loadLibrary("usb-1.0");
System.loadLibrary("opensc");
System.loadLibrary("usb-android");
```

**No Readers Found**
- Verify USB OTG cable/adapter connected
- Check device supports USB host mode
- Ensure reader is CCID-compliant
- Check logcat: `adb logcat | grep OpenSC`

**Card Not Detected**
- Ensure card is properly inserted
- Try removing and reinserting card
- Check reader LED indicators
- Verify reader power via USB

### OpenSSL-Specific Issues

**Build Errors**

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

**OpenSSL Not Detected by OpenSC**

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

**Runtime Issues**

**"dlopen failed: library not found"**
- Ensure libcrypto.so and libssl.so are in jniLibs/[ABI]/
- Load crypto and ssl before opensc
- Check ABI matches device architecture

**"symbol not found"**
- Rebuild with same NDK version
- Ensure all libraries use same API level
- Verify library loading order

---

## Advanced Topics

### Custom API Level

Edit the scripts and change the `API_LEVEL` variable:

```bash
# In build-libusb-android.sh and build-opensc-android.sh
API_LEVEL=23  # Android 6.0
```

### Adding OpenSSL Support

1. Build OpenSSL for Android using `build-openssl-android.sh`
2. Place built libraries in `build-android/openssl-install/[ABI]/`
3. Re-run `build-opensc-android.sh`

The script will automatically detect and use OpenSSL if available.

### Custom libusb Version

Edit `build-libusb-android.sh`:

```bash
LIBUSB_VERSION="1.0.26"  # Change to desired version
```

### Custom OpenSSL Version

Edit `build-openssl-android.sh`:

```bash
OPENSSL_VERSION="3.2.1"  # Change to desired version
OPENSSL_URL="https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz"
```

Supported versions: OpenSSL 3.0.x and 3.x.x

### Clean Build

To start fresh:

```bash
# Remove build directory
rm -rf build-android/

# Clean OpenSC source
make clean  # if previously built for host

# Rebuild
./build-openssl-android.sh all    # Optional
./build-libusb-android.sh all
./build-opensc-android.sh all
```

Or use the cleanup script:

```bash
./clean-android-build.sh        # Interactive cleanup
./clean-android-build.sh -f     # Force cleanup without prompt
```

### Testing Your Setup

After building, you can test with an Android device:

1. Connect a CCID reader via USB OTG
2. Grant USB permissions
3. Use `opensc-tool` to list readers:
   ```bash
   adb push build-android/opensc-install/arm64-v8a/bin/opensc-tool /data/local/tmp/
   adb shell chmod 755 /data/local/tmp/opensc-tool
   adb shell /data/local/tmp/opensc-tool --list-readers
   ```

### Performance

**Build Times** (modern hardware):
- OpenSSL (all ABIs): ~40-60 minutes
- libusb (all ABIs): ~5-10 minutes
- OpenSC (all ABIs): ~15-30 minutes
- **Total with OpenSSL**: ~60-100 minutes
- **Total without OpenSSL**: ~20-40 minutes

**Single Architecture** (e.g., arm64-v8a):
- OpenSSL: ~10 minutes
- libusb: ~2 minutes
- OpenSC: ~5 minutes
- **Total**: ~17 minutes

**Disk Space:**
- Build artifacts: ~500 MB
- Final libraries (all ABIs): ~10-15 MB

### File Sizes

**Approximate sizes after building:**
- `libopensc.so`: ~500 KB - 1 MB
- `opensc-pkcs11.so`: ~600 KB - 1.2 MB
- `libusb-1.0.so`: ~50-100 KB
- `libcrypto.so`: ~3-4 MB (if using OpenSSL)
- `libssl.so`: ~500 KB (if using OpenSSL)
- **Total per architecture**: ~2-3 MB (without OpenSSL) or ~5-7 MB (with OpenSSL)

---

## Resources

### Build Scripts

| Script | Description |
|--------|-------------|
| `build-openssl-android.sh` | Build OpenSSL for Android |
| `build-libusb-android.sh` | Build libusb for Android |
| `build-opensc-android.sh` | Build OpenSC for Android |
| `clean-android-build.sh` | Clean build artifacts |

### Documentation

| Document | Purpose |
|----------|---------|
| This file | Complete guide with all topics |
| `android/README.md` | Integration layer API reference |
| `pdf-signer/README.md` | PDF signing with OpenSC |

### External Resources

- **OpenSC Wiki:** https://github.com/OpenSC/OpenSC/wiki
- **libusb Documentation:** https://libusb.info/
- **OpenSSL Documentation:** https://www.openssl.org/docs/
- **Android NDK Guide:** https://developer.android.com/ndk
- **Android USB Host:** https://developer.android.com/guide/topics/connectivity/usb/host
- **CCID Specification:** https://www.usb.org/document-library/smart-card-ccid

### Use Cases

1. **Smart Card Authentication**: Use smart cards for user authentication in enterprise Android apps
2. **Digital Signatures**: Sign documents using certificates stored on smart cards
3. **Encryption/Decryption**: Use smart card cryptographic capabilities
4. **NFC Card Reading**: Read contactless smart cards (with appropriate readers)
5. **Government ID Cards**: Access national ID cards (eID, DNIe, etc.)

### PDF Digital Signature Tool

A complete **PDF signing solution** is included that uses your OpenSC Android middleware with Apache PDFBox to sign PDFs using physical hardware tokens.

**Features:**
- ✅ Desktop & Android - Full implementations for both platforms
- ✅ Hardware Token Support - YubiKey, Nitrokey, CAC, PIV, eToken, etc.
- ✅ PKCS#11 Integration - Uses OpenSC PKCS#11 middleware
- ✅ Adobe-Compatible - Industry-standard PKCS#7 detached signatures
- ✅ USB OTG on Android - Sign PDFs on mobile with USB smart card readers

**Location:** All PDF signer code is in the `pdf-signer/` directory

See `pdf-signer/README.md` for complete documentation.

---

## License

- **OpenSC:** LGPL 2.1+
- **libusb:** LGPL 2.1+
- **OpenSSL:** Apache License 2.0 (3.x) / OpenSSL License (older)

When distributing your Android app with OpenSC, ensure compliance with these licenses.

---

## Support

### Getting Help

1. **Check documentation** - This comprehensive guide
2. **Review examples** - Working code in `android/README.md`
3. **Check logs** - Use `adb logcat | grep OpenSC`
4. **GitHub Issues** - https://github.com/OpenSC/OpenSC/issues

### Common Questions

**Q: Do I need OpenSSL?**
A: Optional but recommended. OpenSC works without it but with reduced cryptographic functionality.

**Q: Which architectures should I build?**
A: For production: arm64-v8a + armeabi-v7a. For testing: arm64-v8a only.

**Q: How big is the APK increase?**
A: ~5-7 MB per architecture. For 2 architectures: ~10-14 MB total.

**Q: Does this work with NFC readers?**
A: Yes, if the NFC reader has CCID support (like ACR122U).

**Q: Can I use this without USB OTG?**
A: No, USB OTG is required for connecting USB smart card readers.

---

## Summary

This complete Android integration system provides:

✅ **Full cross-compilation** for OpenSSL, libusb, and OpenSC
✅ **USB Host API integration** with Android permissions
✅ **JNI wrapper** for easy Java integration
✅ **Simple high-level API** for Android apps
✅ **Complete documentation** with working examples
✅ **Production-ready** build system

**Ready to use for:**
- Enterprise smart card authentication
- Digital signature applications
- Government eID integration
- Banking/finance applications
- Healthcare systems
- Any CCID smart card reader application on Android

---

**Created for OpenSC Android Integration Project**
**Last Updated:** December 26, 2024
