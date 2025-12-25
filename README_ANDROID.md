# OpenSC for Android with libusb and CCID Support

Complete cross-compilation setup for building OpenSC with USB CCID smart card reader support on Android.

## 📋 Overview

This build system enables OpenSC to communicate directly with CCID-compliant USB smart card readers on Android devices through USB OTG (On-The-Go) connections. It achieves this by:

1. **Cross-compiling libusb** for Android to provide low-level USB communication
2. **Building OpenSC** with libusb support instead of PC/SC (which isn't available on Android)
3. **Enabling CCID protocol** over direct USB for smart card operations

## 🚀 Quick Start

```bash
# 1. Install Android NDK and set path
export ANDROID_NDK_ROOT=/path/to/android-ndk

# 2. Build libusb for Android
./build-libusb-android.sh all

# 3. Build OpenSC for Android
./build-opensc-android.sh all

# 4. Your libraries are ready!
ls build-android/opensc-install/arm64-v8a/lib/
```

**See [ANDROID_QUICK_START.md](ANDROID_QUICK_START.md) for detailed quick start guide.**

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [ANDROID_QUICK_START.md](ANDROID_QUICK_START.md) | Fast track guide - get building in 5 minutes |
| [ANDROID_BUILD.md](ANDROID_BUILD.md) | Complete build documentation with troubleshooting |
| This README | Overview and file descriptions |

## 🔧 Build Scripts

### 1. `build-libusb-android.sh`

Cross-compiles libusb for Android architectures.

**Features:**
- Downloads libusb v1.0.27 automatically
- Supports all Android ABIs (arm64-v8a, armeabi-v7a, x86_64, x86)
- Builds both static and shared libraries
- Configured for Android with system log support

**Usage:**
```bash
./build-libusb-android.sh all           # All architectures
./build-libusb-android.sh arm64-v8a     # Single architecture
```

**Output:** `build-android/install/[ABI]/`

### 2. `build-opensc-android.sh`

Cross-compiles OpenSC with libusb support for Android.

**Features:**
- Automatic detection of cross-compiled libusb
- Optional OpenSSL support (auto-detected)
- PC/SC disabled (uses libusb instead)
- Stripped binaries for smaller size
- Builds libraries and command-line tools

**Usage:**
```bash
./build-opensc-android.sh all           # All architectures
./build-opensc-android.sh arm64-v8a     # Single architecture
```

**Requirements:** Must run `build-libusb-android.sh` first

**Output:** `build-android/opensc-install/[ABI]/`

### 3. `clean-android-build.sh`

Removes all Android build artifacts.

**Usage:**
```bash
./clean-android-build.sh        # Interactive cleanup
./clean-android-build.sh -f     # Force cleanup without prompt
```

## 📦 Build Output Structure

```
build-android/
├── libusb-1.0.27.tar.bz2                    # Downloaded source
├── libusb-1.0.27/                           # Extracted source
│   └── build-[ABI]/                         # Build directory per ABI
│
├── install/                                 # libusb installation
│   └── [ABI]/
│       ├── lib/
│       │   ├── libusb-1.0.a                # Static library
│       │   ├── libusb-1.0.so               # Shared library
│       │   └── pkgconfig/libusb-1.0.pc     # pkg-config file
│       └── include/libusb-1.0/             # Headers
│
├── opensc-build-[ABI]/                      # OpenSC build directory
│
└── opensc-install/                          # OpenSC installation
    └── [ABI]/
        ├── lib/
        │   ├── libopensc.so                # Core library
        │   ├── opensc-pkcs11.so            # PKCS#11 module
        │   ├── onepin-opensc-pkcs11.so     # One-pin PKCS#11
        │   ├── pkcs11-spy.so               # PKCS#11 debugging
        │   └── pkcs15init.so               # Card initialization
        ├── bin/
        │   ├── opensc-tool                 # General OpenSC tool
        │   ├── pkcs11-tool                 # PKCS#11 operations
        │   ├── pkcs15-tool                 # PKCS#15 operations
        │   ├── pkcs15-init                 # Card initialization
        │   ├── pkcs15-crypt                # Cryptographic operations
        │   ├── cardos-tool                 # CardOS specific
        │   ├── cryptoflex-tool             # Cryptoflex specific
        │   └── ...                         # More tools
        └── etc/
            └── opensc.conf                 # Configuration file
```

## 🏗️ Architecture Support

| ABI | Description | Priority | Typical Use |
|-----|-------------|----------|-------------|
| arm64-v8a | 64-bit ARM | **High** | Modern Android phones/tablets (2018+) |
| armeabi-v7a | 32-bit ARM | Medium | Older Android devices |
| x86_64 | 64-bit x86 | Low | Android emulators |
| x86 | 32-bit x86 | Low | Older emulators |

**Recommendation:** Build `arm64-v8a` for most modern devices, add `armeabi-v7a` for broader compatibility.

## 🔑 Key Features

### Enabled
✅ **Direct USB Communication** - Via libusb (no PC/SC needed)
✅ **CCID Protocol** - Full CCID support for smart card readers
✅ **USB OTG Support** - Works with USB On-The-Go on Android
✅ **All Card Types** - Supports all OpenSC-compatible smart cards
✅ **PKCS#11** - Complete PKCS#11 interface
✅ **PKCS#15** - PKCS#15 file system support
✅ **Command Tools** - Full suite of command-line utilities

### Disabled (Not Available on Android)
❌ **PC/SC** - Not available on Android (replaced by libusb)
❌ **CryptoTokenKit** - macOS only
❌ **CT-API** - Legacy interface
❌ **OpenCT** - Alternative reader interface
❌ **Desktop Notifications** - Not applicable to Android

## 🔌 CCID Reader Support

Works with most CCID-compliant USB smart card readers:

- ✓ Generic CCID readers
- ✓ ACR122U (NFC reader)
- ✓ Gemalto readers
- ✓ Identiv/SCM readers
- ✓ HID Omnikey readers
- ✓ YubiKey (in CCID mode)
- ✓ Most USB-based contact and contactless readers

**Requirement:** Reader must support CCID protocol and be USB-connected

## 📱 Android Integration

### Minimum Requirements
- **Android Version:** 5.0 (API 21) or higher
- **Hardware:** USB OTG support
- **Permissions:** USB host mode

### Android App Setup

1. **Add libraries to your app:**
   ```
   app/src/main/jniLibs/arm64-v8a/
   ├── libopensc.so
   ├── libusb-1.0.so
   └── opensc-pkcs11.so
   ```

2. **Add permissions in AndroidManifest.xml:**
   ```xml
   <uses-permission android:name="android.hardware.usb.host" />
   <uses-feature android:name="android.hardware.usb.host" />
   ```

3. **Request USB device access in your app**

4. **Use OpenSC via JNI or execute tools via NDK**

See [ANDROID_BUILD.md](ANDROID_BUILD.md) for detailed integration instructions and code examples.

## 🛠️ Prerequisites

### Build Environment

**Android NDK:**
- Version r21 or later (r25+ recommended)
- Download: https://developer.android.com/ndk/downloads
- Must set `ANDROID_NDK_ROOT` environment variable

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

## 📊 Build Configuration

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

## 🧪 Testing

### On Android Device

1. Build for your device architecture (usually `arm64-v8a`)
2. Push binaries to device via adb
3. Connect USB smart card reader via OTG adapter
4. Grant USB permissions
5. Run `opensc-tool --list-readers`

### On Android Emulator

1. Build for `x86_64` (64-bit emulator)
2. Push and test as above
3. Note: USB passthrough may not work in all emulators

**Detailed testing instructions:** [ANDROID_BUILD.md](ANDROID_BUILD.md)

## 🐛 Troubleshooting

### Common Issues

**"ANDROID_NDK_ROOT is not set"**
```bash
export ANDROID_NDK_ROOT=/path/to/android-ndk
```

**"libusb not found"**
```bash
./build-libusb-android.sh arm64-v8a
```

**"configure: command not found"**
```bash
./bootstrap
```

**USB device not found in app**
- Verify USB OTG support
- Check USB permissions
- Confirm CCID reader compatibility

**Full troubleshooting guide:** [ANDROID_BUILD.md](ANDROID_BUILD.md)

## 📈 Build Performance

**Approximate build times** (modern hardware):
- libusb (all ABIs): 5-10 minutes
- OpenSC (all ABIs): 15-30 minutes
- Single ABI: 5-10 minutes total

**Disk space:**
- Build artifacts: ~500 MB
- Final libraries (all ABIs): ~10-15 MB

## 🔄 Workflow

### Initial Build
```bash
export ANDROID_NDK_ROOT=/path/to/ndk
./build-libusb-android.sh all
./build-opensc-android.sh all
```

### Rebuild After Code Changes
```bash
# Clean previous build
./clean-android-build.sh -f

# Rebuild
./build-libusb-android.sh all
./build-opensc-android.sh all
```

### Build Single Architecture (Fast)
```bash
./build-libusb-android.sh arm64-v8a
./build-opensc-android.sh arm64-v8a
```

## 🎯 Use Cases

1. **Enterprise Authentication** - Smart card login for Android enterprise apps
2. **Digital Signatures** - Sign documents with smart card certificates
3. **Encryption/Decryption** - Use smart card crypto capabilities
4. **Government eID** - Access national ID cards (eID, DNIe, etc.)
5. **Banking/Finance** - Smart card-based authentication
6. **Healthcare** - Medical professional cards
7. **NFC Card Reading** - Read contactless cards with NFC readers

## 📄 License

- **OpenSC:** LGPL 2.1+
- **libusb:** LGPL 2.1+

Ensure compliance with these licenses when distributing your Android app.

## 🤝 Contributing

OpenSC is an open-source project. Contributions welcome!

- **Report Issues:** https://github.com/OpenSC/OpenSC/issues
- **Documentation:** https://github.com/OpenSC/OpenSC/wiki
- **Discussions:** https://github.com/OpenSC/OpenSC/discussions

## 📚 Additional Resources

- **OpenSC Wiki:** https://github.com/OpenSC/OpenSC/wiki
- **libusb Documentation:** https://libusb.info/
- **Android NDK Guide:** https://developer.android.com/ndk
- **Android USB Host:** https://developer.android.com/guide/topics/connectivity/usb/host
- **CCID Specification:** https://www.usb.org/document-library/smart-card-ccid

## 📞 Support

1. Check documentation: [ANDROID_BUILD.md](ANDROID_BUILD.md)
2. Review troubleshooting section
3. Check build logs in `build-android/` subdirectories
4. Search existing issues: https://github.com/OpenSC/OpenSC/issues
5. Open new issue if needed

## ✅ Status

**Build System:** Production-ready
**libusb Version:** 1.0.27
**Target Android API:** 21 (Android 5.0+)
**Tested Architectures:** arm64-v8a, armeabi-v7a, x86_64, x86
**Tested NDK Versions:** r21, r23, r25

---

**Ready to build?** Start with [ANDROID_QUICK_START.md](ANDROID_QUICK_START.md)!
