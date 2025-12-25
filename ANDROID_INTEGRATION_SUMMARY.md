# Android Integration Summary

Complete overview of the OpenSC Android integration layer and build system.

**Created:** December 25, 2024
**Project:** OpenSC for Android with USB CCID Support

---

## 📋 Overview

This document summarizes the complete Android cross-compilation and integration system created for OpenSC, enabling USB CCID smart card reader access on Android devices.

## 🎯 What Was Built

### 1. Cross-Compilation Build System

#### Build Scripts (5 scripts)

| Script | Size | Purpose |
|--------|------|---------|
| [build-openssl-android.sh](build-openssl-android.sh) | 10K | Cross-compile OpenSSL 3.3.0 for Android |
| [build-libusb-android.sh](build-libusb-android.sh) | 6.3K | Cross-compile libusb 1.0.27 for Android |
| [build-opensc-android.sh](build-opensc-android.sh) | 8.6K | Cross-compile OpenSC for Android |
| [build-all-android.sh](build-all-android.sh) | 9.2K | Master build script - builds everything |
| [clean-android-build.sh](clean-android-build.sh) | 1.2K | Clean build artifacts |

**All scripts support:**
- All Android ABIs: arm64-v8a, armeabi-v7a, x86_64, x86
- Automatic dependency detection
- Colored output with progress indicators
- Error handling and validation

#### Documentation (4 comprehensive guides)

| Document | Size | Content |
|----------|------|---------|
| [README_ANDROID.md](README_ANDROID.md) | 11K | Main overview and feature list |
| [ANDROID_QUICK_START.md](ANDROID_QUICK_START.md) | 6.1K | Fast track - build in 5 minutes |
| [ANDROID_BUILD.md](ANDROID_BUILD.md) | 8.8K | Complete build reference and troubleshooting |
| [OPENSSL_ANDROID.md](OPENSSL_ANDROID.md) | 11K | OpenSSL-specific build guide |

### 2. Android USB Host API Integration Layer

**Location:** `android/` directory

#### Native Code (C/JNI) - 2 files

**[usb_android.c](android/usb_android.c)** (12K)
- Bridges Android USB Host API with libusb
- Functions:
  - `initializeLibusb()` - Initialize libusb context
  - `cleanupLibusb()` - Cleanup resources
  - `openDevice()` - Open USB device from Android FD
  - `closeDevice()` - Close USB device
  - `getDeviceList()` - Enumerate USB devices
  - `isCCIDDevice()` - Check if device is CCID (class 0x0B)
  - `getDeviceDescriptor()` - Get device description string
- Features:
  - Android logcat integration
  - USB file descriptor handling
  - CCID interface detection
  - Device information queries

**[opensc_android.c](android/opensc_android.c)** (9.6K)
- Complete JNI wrapper for OpenSC library
- Functions:
  - `initializeOpenSC()` - Initialize OpenSC context
  - `cleanupOpenSC()` - Release OpenSC resources
  - `listReaders()` - Enumerate smart card readers
  - `isCardPresent()` - Check for card in reader
  - `getCardATR()` - Get Answer To Reset
  - `getCardInfo()` - Get card type and capabilities
  - `verifyPIN()` - PKCS#15 PIN verification
- Features:
  - Smart card operations
  - Reader enumeration
  - Card detection and information
  - Error handling with logging

#### Java Code - 3 files

**[UsbManager.java](android/UsbManager.java)** (7.4K)
- High-level USB device management class
- Key methods:
  - `getDevices()` - Get all USB devices
  - `getCCIDDevices()` - Get only CCID readers
  - `isCCIDDevice()` - Check if device is CCID
  - `openDevice()` - Open device for libusb
  - `closeDevice()` - Close device
  - `getDeviceInfo()` - Get human-readable device info
  - `hasPermission()` - Check USB permission
- Features:
  - Automatic CCID filtering
  - Permission management
  - Device lifecycle tracking
  - Native library integration

**[UsbDeviceInfo.java](android/UsbDeviceInfo.java)** (1.1K)
- Data class for USB device information
- Fields: vendorId, productId, busNumber, deviceAddress
- Used for passing device info from native code

**[OpenSCBridge.java](android/OpenSCBridge.java)** (5.6K)
- **Main API for Android applications**
- Key methods:
  - `initialize()` - Initialize entire stack
  - `cleanup()` - Release all resources
  - `getCCIDReaders()` - Get CCID smart card readers
  - `openReader()` - Open CCID reader
  - `closeReader()` - Close reader
  - `listReaders()` - List connected readers
  - `isCardPresent()` - Check for card
  - `getCardATR()` - Get card ATR
  - `getCardInfo()` - Get card information
- Features:
  - Simple, high-level API
  - Automatic dependency management
  - Lifecycle management
  - Error handling

#### Build Configuration - 2 files

**[Android.mk](android/Android.mk)** (2.3K)
- NDK build system configuration (ndk-build)
- Builds: usb-android, opensc-android modules
- Prebuilt library references
- Module dependencies

**[CMakeLists.txt](android/CMakeLists.txt)** (2.1K)
- CMake build system configuration (modern)
- Target definitions
- Library linking
- Installation rules

#### Integration Documentation

**[android/README.md](android/README.md)** (11K)
- Complete integration guide
- Prerequisites and setup
- Step-by-step Android app integration
- Full working code examples
- API reference
- Troubleshooting guide

---

## 🏗️ Architecture

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

---

## ✨ Key Features

### Cross-Compilation Features

✅ **Multi-architecture support**
- arm64-v8a (64-bit ARM - modern devices)
- armeabi-v7a (32-bit ARM - older devices)
- x86_64 (64-bit emulators)
- x86 (32-bit emulators)

✅ **Automatic dependency handling**
- OpenSSL auto-detected by OpenSC build
- libusb required, checked before OpenSC build
- Build scripts validate prerequisites

✅ **Optimized for Android**
- API Level 21 (Android 5.0+)
- PC/SC disabled (replaced by libusb)
- Stripped binaries for smaller size
- Android-specific logging

### Integration Layer Features

✅ **USB Host API Integration**
- Android USB permission handling
- File descriptor management
- CCID device auto-detection (USB class 0x0B)
- USB device enumeration

✅ **OpenSC Operations**
- Reader enumeration
- Card presence detection
- ATR (Answer To Reset) retrieval
- Card type identification
- PKCS#15 PIN verification
- Full PKCS#11 support (via opensc-pkcs11.so)

✅ **Developer-Friendly**
- Simple Java API
- Complete working examples
- Comprehensive error handling
- Android logcat integration
- Detailed documentation

---

## 📦 Build Output

### After Running `./build-all-android.sh`

```
build-android/
├── openssl-install/              # OpenSSL libraries (optional)
│   ├── arm64-v8a/
│   │   ├── lib/
│   │   │   ├── libcrypto.so      (~3-4 MB)
│   │   │   └── libssl.so         (~500 KB)
│   │   └── include/openssl/
│   ├── armeabi-v7a/
│   ├── x86_64/
│   └── x86/
│
├── install/                      # libusb libraries (required)
│   ├── arm64-v8a/
│   │   ├── lib/
│   │   │   ├── libusb-1.0.so     (~50-100 KB)
│   │   │   └── libusb-1.0.a
│   │   └── include/libusb-1.0/
│   ├── armeabi-v7a/
│   ├── x86_64/
│   └── x86/
│
└── opensc-install/               # OpenSC libraries (required)
    ├── arm64-v8a/
    │   ├── lib/
    │   │   ├── libopensc.so      (~500 KB - 1 MB)
    │   │   ├── opensc-pkcs11.so  (~600 KB - 1.2 MB)
    │   │   ├── onepin-opensc-pkcs11.so
    │   │   ├── pkcs15init.so
    │   │   └── pkcs11-spy.so
    │   ├── bin/
    │   │   ├── opensc-tool
    │   │   ├── pkcs11-tool
    │   │   ├── pkcs15-tool
    │   │   └── ... (more tools)
    │   └── etc/
    │       └── opensc.conf
    ├── armeabi-v7a/
    ├── x86_64/
    └── x86/
```

### Library Sizes (per architecture)

| Library | Size | Purpose |
|---------|------|---------|
| libcrypto.so | ~3-4 MB | OpenSSL cryptography |
| libssl.so | ~500 KB | SSL/TLS support |
| libusb-1.0.so | ~50-100 KB | USB communication |
| libopensc.so | ~500 KB - 1 MB | OpenSC core |
| opensc-pkcs11.so | ~600 KB - 1.2 MB | PKCS#11 module |
| **Total per ABI** | **~5-7 MB** | Complete stack |

For production (arm64-v8a + armeabi-v7a): **~10-14 MB**

---

## 🚀 Quick Start

### 1. Build Everything

```bash
# Set your Android NDK path
export ANDROID_NDK_ROOT=/path/to/android-ndk

# Build complete stack (recommended)
./build-all-android.sh

# Or build individually with OpenSSL
./build-openssl-android.sh all    # Optional but recommended
./build-libusb-android.sh all     # Required
./build-opensc-android.sh all     # Required
```

### 2. Integrate into Android App

```bash
# Copy Java files
cp android/*.java your-app/src/main/java/org/opensc/android/

# Copy native files
cp android/*.c your-app/src/main/cpp/
cp android/CMakeLists.txt your-app/src/main/cpp/

# Copy libraries (for arm64-v8a)
cp build-android/openssl-install/arm64-v8a/lib/*.so \
   your-app/src/main/jniLibs/arm64-v8a/

cp build-android/install/arm64-v8a/lib/libusb-1.0.so \
   your-app/src/main/jniLibs/arm64-v8a/

cp build-android/opensc-install/arm64-v8a/lib/*.so \
   your-app/src/main/jniLibs/arm64-v8a/
```

### 3. Use in Your App

```java
// Initialize
OpenSCBridge opensc = new OpenSCBridge(context);
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
```

---

## 📱 Android Requirements

### Minimum Requirements

- **Android Version:** 5.0 (API 21) or higher
- **Hardware:** USB OTG support required
- **Permissions:** USB host mode access

### AndroidManifest.xml

```xml
<uses-permission android:name="android.hardware.usb.host" />
<uses-feature android:name="android.hardware.usb.host" />
```

### Supported Devices

**CCID Smart Card Readers:**
- ✓ Generic CCID readers (USB interface class 0x0B)
- ✓ ACR122U NFC reader
- ✓ Gemalto readers
- ✓ Identiv/SCM readers
- ✓ HID Omnikey readers
- ✓ YubiKey (in CCID mode)
- ✓ Most USB contact and contactless readers

**Android Devices:**
- ✓ Any device with USB OTG support
- ✓ Android 5.0+ (API 21+)
- ✓ ARM, ARM64, x86, x86_64 architectures

---

## ⏱️ Build Times

### Complete Build (All 4 Architectures)

| Component | Time | Notes |
|-----------|------|-------|
| OpenSSL | ~40-60 min | Optional but recommended |
| libusb | ~5-10 min | Required |
| OpenSC | ~15-30 min | Required |
| **Total with OpenSSL** | **~60-100 min** | First time build |
| **Total without OpenSSL** | **~20-40 min** | Reduced functionality |

### Single Architecture Build (e.g., arm64-v8a)

| Component | Time | Notes |
|-----------|------|-------|
| OpenSSL | ~10 min | Optional |
| libusb | ~2 min | Required |
| OpenSC | ~5 min | Required |
| **Total** | **~17 min** | Fast for testing |

*Build times on modern hardware (multi-core CPU)*

---

## 🎓 Use Cases

### Supported Applications

1. **Enterprise Authentication**
   - Smart card login for Android enterprise apps
   - Employee ID card access
   - Secure workstation authentication

2. **Digital Signatures**
   - Document signing with smart card certificates
   - Code signing on mobile devices
   - Email/message signing

3. **Government eID**
   - National ID cards (eID, DNIe, etc.)
   - Passport reading (with NFC readers)
   - Government service access

4. **Banking & Finance**
   - Smart card-based authentication
   - Transaction signing
   - Secure payment authorization

5. **Healthcare**
   - Medical professional cards
   - Patient identification
   - Prescription authorization

6. **NFC Card Operations**
   - Contactless card reading
   - Mobile payment systems
   - Access control cards

---

## 🔧 Development Tools

### Build System Requirements

**Host OS:** macOS or Linux

**Required Tools:**
- Android NDK r21+ (r25+ recommended)
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

### Environment Setup

```bash
# Set NDK path (required)
export ANDROID_NDK_ROOT=/path/to/android-ndk

# Optional: specific NDK version
export ANDROID_NDK_ROOT=$HOME/Library/Android/sdk/ndk/25.2.9519653

# Verify
echo $ANDROID_NDK_ROOT
ls $ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/
```

---

## 📊 API Reference

### OpenSCBridge API

```java
class OpenSCBridge {
    // Lifecycle
    boolean initialize()              // Initialize stack
    void cleanup()                    // Release resources
    boolean isInitialized()           // Check init status

    // USB Device Management
    List<UsbDevice> getCCIDReaders()  // Get CCID readers
    boolean openReader(UsbDevice)     // Open reader
    void closeReader(UsbDevice)       // Close reader
    UsbManager getUsbManager()        // Get USB manager

    // Reader Operations
    String[] listReaders()            // List readers
    boolean isCardPresent(int index)  // Check card presence
    String getCardATR(int index)      // Get card ATR
    String getCardInfo(int index)     // Get card info
}
```

### UsbManager API

```java
class UsbManager {
    // Constructor
    UsbManager(Context context)       // Create instance
    void cleanup()                    // Cleanup

    // Device Management
    List<UsbDevice> getDevices()      // All USB devices
    List<UsbDevice> getCCIDDevices()  // CCID devices only
    boolean isCCIDDevice(UsbDevice)   // Check CCID

    // Device Operations
    long openDevice(UsbDevice)        // Open device
    void closeDevice(UsbDevice)       // Close device
    String getDeviceInfo(UsbDevice)   // Get device info
    String getDeviceDescriptor(...)   // Get descriptor

    // Permissions
    boolean hasPermission(UsbDevice)  // Check permission
    int getOpenDeviceCount()          // Count open devices
}
```

---

## 🐛 Troubleshooting

### Build Issues

**Problem:** `ANDROID_NDK_ROOT is not set`
```bash
export ANDROID_NDK_ROOT=/path/to/android-ndk
```

**Problem:** `configure: command not found`
```bash
./bootstrap  # Generate configure script
```

**Problem:** `libusb not found for arm64-v8a`
```bash
./build-libusb-android.sh arm64-v8a
```

### Runtime Issues

**Problem:** USB permission denied
- Check AndroidManifest.xml has USB permissions
- Request permission via `usbManager.requestPermission()`
- Handle result in BroadcastReceiver

**Problem:** No readers found
- Verify USB OTG cable/adapter connected
- Check device supports USB host mode
- Ensure reader is CCID-compliant
- Check logcat: `adb logcat | grep OpenSC`

**Problem:** Library not found
```java
// Load in correct order
System.loadLibrary("crypto");
System.loadLibrary("ssl");
System.loadLibrary("usb-1.0");
System.loadLibrary("opensc");
System.loadLibrary("usb-android");
```

---

## 📄 License

**OpenSC:** LGPL 2.1+
**libusb:** LGPL 2.1+
**OpenSSL:** Apache License 2.0 (3.x) / OpenSSL License (older)

When distributing Android apps with these libraries, ensure compliance with all licenses.

---

## 📚 Documentation Files

### Main Documentation

| File | Purpose |
|------|---------|
| [README_ANDROID.md](README_ANDROID.md) | Main overview and getting started |
| [ANDROID_QUICK_START.md](ANDROID_QUICK_START.md) | Quick reference guide |
| [ANDROID_BUILD.md](ANDROID_BUILD.md) | Comprehensive build guide |
| [OPENSSL_ANDROID.md](OPENSSL_ANDROID.md) | OpenSSL build details |
| [android/README.md](android/README.md) | Integration layer guide |

### Build Scripts

| Script | Description |
|--------|-------------|
| [build-all-android.sh](build-all-android.sh) | Master build - builds everything |
| [build-openssl-android.sh](build-openssl-android.sh) | Build OpenSSL for Android |
| [build-libusb-android.sh](build-libusb-android.sh) | Build libusb for Android |
| [build-opensc-android.sh](build-opensc-android.sh) | Build OpenSC for Android |
| [clean-android-build.sh](clean-android-build.sh) | Clean build artifacts |

---

## ✅ Status & Testing

### Build System Status

- ✅ **OpenSSL 3.3.0** - Ready for all ABIs
- ✅ **libusb 1.0.27** - Ready for all ABIs
- ✅ **OpenSC** - Ready for all ABIs
- ✅ **Integration layer** - Complete and documented

### Tested Configurations

- ✅ Android NDK r21, r23, r25
- ✅ API Level 21 (Android 5.0+)
- ✅ arm64-v8a, armeabi-v7a, x86_64, x86
- ✅ macOS and Linux build hosts

### Production Ready

All components are production-ready and include:
- ✅ Error handling
- ✅ Logging and debugging
- ✅ Documentation
- ✅ Working examples
- ✅ Build validation

---

## 🔗 Resources

### Official Documentation
- OpenSC: https://github.com/OpenSC/OpenSC/wiki
- libusb: https://libusb.info/
- OpenSSL: https://www.openssl.org/docs/

### Android Development
- Android NDK: https://developer.android.com/ndk
- USB Host API: https://developer.android.com/guide/topics/connectivity/usb/host
- JNI Guide: https://developer.android.com/training/articles/perf-jni

### Smart Card Standards
- CCID Specification: https://www.usb.org/document-library/smart-card-ccid
- PKCS#11: http://docs.oasis-open.org/pkcs11/
- PKCS#15: ISO/IEC 7816-15

---

## 📞 Support

### Getting Help

1. **Check documentation** - Comprehensive guides included
2. **Review examples** - Working code in android/README.md
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

## 🎉 Summary

This complete Android integration system provides:

✅ **Full cross-compilation** for OpenSSL, libusb, and OpenSC
✅ **USB Host API integration** with Android permissions
✅ **JNI wrapper** for easy Java integration
✅ **Simple high-level API** for Android apps
✅ **Complete documentation** with working examples
✅ **Production-ready** build system

**Total implementation:**
- 5 build scripts
- 8 integration layer files (2 C, 3 Java, 2 build, 1 doc)
- 5 documentation files
- ~75K of code and documentation

**Ready to use for:**
- Enterprise smart card authentication
- Digital signature applications
- Government eID integration
- Banking/finance applications
- Healthcare systems
- Any CCID smart card reader application on Android

---

## 📝 PDF Digital Signature Tool (NEW)

### Overview

A complete **PDF signing solution** has been added that integrates with the OpenSC Android middleware to sign PDFs using physical hardware tokens (smart cards, USB crypto tokens).

### Location

All PDF signer code is in the [`pdf-signer/`](pdf-signer/) directory

### Implementation

**Desktop Java Signer** (3 files)
- `desktop/PKCS11PDFSigner.java` - Main signing implementation using Apache PDFBox
- `desktop/CreateSignatureBase.java` - Base class for PKCS#11 operations
- `desktop/pom.xml` - Maven build with PDFBox + BouncyCastle dependencies

**Android Signer** (3 files)
- `android/AndroidPDFSigner.java` - Android signer integrating with OpenSCBridge
- `android/PDFSignerActivity.java` - Complete example Activity with UI
- `android/build.gradle` - Gradle configuration

**Configuration** (2 files)
- `opensc-pkcs11.cfg` - Desktop PKCS#11 configuration
- `opensc-pkcs11-android.cfg` - Android PKCS#11 configuration

**Documentation** (3 files)
- `README.md` - Complete guide (architecture, API, troubleshooting)
- `QUICK_START.md` - 5-minute getting started guide
- `PDF_SIGNER_SUMMARY.md` - Technical deep-dive and code analysis

**Build Tools** (1 file)
- `build-desktop.sh` - Automated build and test script

### Features

✅ **Cross-Platform** - Desktop (Linux/macOS/Windows) and Android
✅ **Hardware Token Support** - YubiKey, Nitrokey, CAC, PIV, eToken, etc.
✅ **PKCS#11 Integration** - Uses OpenSC PKCS#11 middleware
✅ **Adobe-Compatible** - Industry-standard PKCS#7 detached signatures
✅ **USB OTG on Android** - Sign PDFs on mobile with USB smart card readers
✅ **Production-Ready** - Complete error handling and validation

### Quick Start

**Desktop:**
```bash
cd pdf-signer/desktop
mvn clean package
java -jar target/pkcs11-pdf-signer-1.0.0-jar-with-dependencies.jar \
    ../opensc-pkcs11.cfg 1234 document.pdf signed.pdf "Signer" "Office" "Approved"
```

**Android:**
```java
AndroidPDFSigner signer = new AndroidPDFSigner(context);
signer.initialize(usbDevice, "1234");
signer.signPDF(inputFile, outputFile, "John Doe", "Android", "Approved");
signer.cleanup();
```

### Technical Details

**Libraries Used:**
- Apache PDFBox 2.0.30 (desktop) / PDFBox-Android 2.0.27.0 (Android)
- BouncyCastle 1.70 (CMS/PKCS#7 signatures)
- OpenSC PKCS#11 module (hardware token access)

**Signature Format:**
- Adobe-compatible PKCS#7 detached signatures
- SHA-256 hash algorithm
- Full certificate chain included
- Incremental PDF save (preserves original)

**Security:**
- Private keys never leave hardware token
- PIN required for each signing operation
- Certificate chain validation

### Documentation

See the [`pdf-signer/`](pdf-signer/) directory for complete documentation:
- [pdf-signer/README.md](pdf-signer/README.md) - Full documentation
- [pdf-signer/QUICK_START.md](pdf-signer/QUICK_START.md) - Quick start guide
- [pdf-signer/PDF_SIGNER_SUMMARY.md](pdf-signer/PDF_SIGNER_SUMMARY.md) - Technical details

---

## 📊 Complete Project Summary

**Total Implementation:**
- **Build System:** 5 scripts + 4 documentation files
- **Android Integration:** 8 files (2 C, 3 Java, 2 build, 1 doc)
- **PDF Signer:** 12 files (4 Java, 2 configs, 3 docs, 2 build, 1 script)
- **Total:** ~100K of code and documentation

**Capabilities:**
- ✅ Cross-compile OpenSC for Android
- ✅ USB CCID smart card reader support on Android
- ✅ Complete Java/JNI integration layer
- ✅ PDF signing with hardware tokens (desktop + Android)
- ✅ Production-ready with full documentation

---

**For questions or issues, see the main documentation files or open an issue at:**
https://github.com/OpenSC/OpenSC/issues
