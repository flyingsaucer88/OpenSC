# Building OpenSC for Android with USB CCID Support

This guide explains how to cross-compile OpenSC for Android with libusb support, enabling direct USB CCID smart card reader communication on Android devices.

## Overview

OpenSC on Android uses libusb for direct USB communication with CCID smart card readers, bypassing the need for PC/SC middleware which is not available on Android. This enables native smart card operations through USB OTG (On-The-Go) connections.

## Prerequisites

### Required Tools

1. **Android NDK (r21 or later)**
   - Download from: https://developer.android.com/ndk/downloads
   - Extract and set environment variable:
     ```bash
     export ANDROID_NDK_ROOT=/path/to/android-ndk-r25c
     ```

2. **Build Tools**
   - autoconf
   - automake
   - libtool
   - pkg-config
   - make
   - curl

   On macOS:
   ```bash
   brew install autoconf automake libtool pkg-config
   ```

   On Linux (Ubuntu/Debian):
   ```bash
   sudo apt-get install autoconf automake libtool pkg-config build-essential curl
   ```

### Optional (for full functionality)

- **OpenSSL for Android**: For cryptographic operations
  - Can be built using openssl-android scripts
  - If not available, OpenSC will build without OpenSSL support

## Build Process

### Step 1: Build libusb for Android

The `build-libusb-android.sh` script downloads and cross-compiles libusb for all Android architectures.

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

### Step 2: Build OpenSC for Android

The `build-opensc-android.sh` script cross-compiles OpenSC with libusb support.

```bash
# Build for all architectures (recommended)
./build-opensc-android.sh all

# Or build for a specific architecture
./build-opensc-android.sh arm64-v8a
```

**Output location:** `build-android/opensc-install/[ABI]/`

**What this builds:**
- Shared libraries: `lib/libopensc.so`, `lib/opensc-pkcs11.so`, etc.
- Command-line tools: `bin/opensc-tool`, `bin/pkcs11-tool`, etc.
- Configuration files: `etc/opensc.conf`

## Configuration Details

### libusb Configuration

The libusb build uses these configure options:
- `--enable-static` - Build static library
- `--enable-shared` - Build shared library
- `--disable-udev` - Disable udev (not available on Android)
- `--enable-system-log` - Enable Android logcat integration

### OpenSC Configuration

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

### API Level

Both scripts target **API level 21 (Android 5.0 Lollipop)** which provides:
- Modern USB host API support
- USB OTG functionality
- Sufficient C standard library features

You can modify the `API_LEVEL` variable in the scripts if you need different compatibility.

## Using OpenSC in Your Android App

### 1. JNI Wrapper Approach (Recommended)

Create JNI wrappers to call OpenSC functions from Java/Kotlin:

```java
// Example JNI interface
public class OpenSCWrapper {
    static {
        System.loadLibrary("opensc");
    }

    public native int initializeCard();
    public native String readCertificate();
    // ... other native methods
}
```

### 2. Command-Line Tools via NDK

Package the OpenSC command-line tools and execute them via NDK:

```kotlin
// Execute opensc-tool command
val process = ProcessBuilder()
    .command("/data/data/your.app.package/lib/opensc-tool", "--list-readers")
    .start()
```

### 3. File Structure in Android App

```
app/src/main/
├── jniLibs/
│   ├── arm64-v8a/
│   │   ├── libopensc.so
│   │   ├── libusb-1.0.so
│   │   └── opensc-pkcs11.so
│   ├── armeabi-v7a/
│   │   └── ...
│   └── x86_64/
│       └── ...
└── assets/
    └── opensc/
        └── opensc.conf
```

### 4. Required Android Permissions

Add to your `AndroidManifest.xml`:

```xml
<manifest>
    <!-- USB host support -->
    <uses-feature android:name="android.hardware.usb.host" />

    <!-- USB permission -->
    <uses-permission android:name="android.hardware.usb.host" />

    <!-- Optional: for OTG detection -->
    <uses-feature
        android:name="android.hardware.usb.accessory"
        android:required="false" />
</manifest>
```

### 5. USB Device Permissions

Request USB device access in your app:

```kotlin
val usbManager = getSystemService(Context.USB_SERVICE) as UsbManager
val device = // ... get USB device
if (!usbManager.hasPermission(device)) {
    val permissionIntent = PendingIntent.getBroadcast(
        this, 0, Intent(ACTION_USB_PERMISSION), 0
    )
    usbManager.requestPermission(device, permissionIntent)
}
```

## CCID USB Communication

### How it Works

1. **USB OTG Connection**: Smart card reader connects via USB OTG adapter
2. **libusb**: Provides low-level USB communication
3. **OpenSC CCID**: Implements CCID protocol over USB
4. **Card Operations**: Standard smart card operations (PKCS#11, etc.)

### Supported Readers

OpenSC with libusb supports most CCID-compliant smart card readers:
- Generic CCID readers
- ACR122U and similar NFC readers
- Gemalto readers
- Identiv readers
- YubiKey (in CCID mode)

### Testing Your Setup

After building, you can test with an Android device:

1. Connect a CCID reader via USB OTG
2. Grant USB permissions
3. Use `opensc-tool` to list readers:
   ```bash
   ./opensc-tool --list-readers
   ```

## Troubleshooting

### NDK Not Found
```bash
Error: ANDROID_NDK_ROOT is not set
```
**Solution**: Set the environment variable:
```bash
export ANDROID_NDK_ROOT=/path/to/android-ndk
```

### Toolchain Not Found
```bash
Error: Toolchain not found at: ...
```
**Solution**: Ensure you have NDK r21 or later with LLVM toolchain.

### libusb Not Found for OpenSC Build
```bash
Error: libusb not found for arm64-v8a
```
**Solution**: Build libusb first:
```bash
./build-libusb-android.sh arm64-v8a
```

### USB Permission Denied in Android App
**Solution**:
1. Check USB permissions in AndroidManifest.xml
2. Request runtime USB device permission
3. Verify USB OTG support on the device

### OpenSSL Not Found
```
Warning: OpenSSL not found for arm64-v8a. Building without OpenSSL support.
```
**Solution**: This is not critical. OpenSC will build with limited cryptographic functionality. For full features, build OpenSSL for Android first.

## Advanced Configuration

### Custom API Level

Edit the scripts and change the `API_LEVEL` variable:

```bash
# In build-libusb-android.sh and build-opensc-android.sh
API_LEVEL=23  # Android 6.0
```

### Adding OpenSSL Support

1. Build OpenSSL for Android using openssl-android or similar
2. Place built libraries in `build-android/openssl-install/[ABI]/`
3. Re-run `build-opensc-android.sh`

The script will automatically detect and use OpenSSL if available.

### Custom libusb Version

Edit `build-libusb-android.sh`:

```bash
LIBUSB_VERSION="1.0.26"  # Change to desired version
```

## Clean Build

To start fresh:

```bash
# Remove build directory
rm -rf build-android/

# Clean OpenSC source
make clean  # if previously built for host

# Rebuild
./build-libusb-android.sh all
./build-opensc-android.sh all
```

## Additional Resources

- **OpenSC Documentation**: https://github.com/OpenSC/OpenSC/wiki
- **libusb Documentation**: https://libusb.info/
- **Android NDK Guide**: https://developer.android.com/ndk/guides
- **Android USB Host**: https://developer.android.com/guide/topics/connectivity/usb/host
- **CCID Specification**: https://www.usb.org/document-library/smart-card-ccid

## Example Use Cases

1. **Smart Card Authentication**: Use smart cards for user authentication in enterprise Android apps
2. **Digital Signatures**: Sign documents using certificates stored on smart cards
3. **Encryption/Decryption**: Use smart card cryptographic capabilities
4. **NFC Card Reading**: Read contactless smart cards (with appropriate readers)
5. **Government ID Cards**: Access national ID cards (eID, DNIe, etc.)

## License

OpenSC is licensed under LGPL 2.1+. libusb is licensed under LGPL 2.1+.

When distributing your Android app with OpenSC, ensure compliance with these licenses.
