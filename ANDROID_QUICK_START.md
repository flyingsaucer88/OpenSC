# Android Build - Quick Start Guide

## TL;DR

```bash
# 1. Set NDK path
export ANDROID_NDK_ROOT=/path/to/android-ndk

# 2. Build libusb for all Android architectures
./build-libusb-android.sh all

# 3. Build OpenSC for all Android architectures
./build-opensc-android.sh all

# 4. Find your compiled libraries
ls build-android/opensc-install/arm64-v8a/lib/
```

## What You Get

After successful build, you'll have:

```
build-android/
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

## Build for Single Architecture

If you only need one architecture (e.g., for testing):

```bash
# Build for 64-bit ARM (most common)
./build-libusb-android.sh arm64-v8a
./build-opensc-android.sh arm64-v8a
```

**Available architectures:**
- `arm64-v8a` - Modern 64-bit ARM devices
- `armeabi-v7a` - Older 32-bit ARM devices
- `x86_64` - 64-bit emulators
- `x86` - 32-bit emulators

## Integrating into Android App

### Step 1: Copy Libraries

Copy the compiled libraries to your Android project:

```bash
# For arm64-v8a architecture
cp build-android/opensc-install/arm64-v8a/lib/*.so \
   /path/to/your/android/app/src/main/jniLibs/arm64-v8a/

cp build-android/install/arm64-v8a/lib/libusb-1.0.so \
   /path/to/your/android/app/src/main/jniLibs/arm64-v8a/
```

### Step 2: Add Permissions

Add to `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.hardware.usb.host" />
<uses-feature android:name="android.hardware.usb.host" />
```

### Step 3: Use in Your App

Create JNI wrapper or use command-line tools via NDK.

See [ANDROID_BUILD.md](ANDROID_BUILD.md) for detailed integration instructions.

## Testing

### On Android Device

1. Build for `arm64-v8a` (or your device's architecture)
2. Push binaries to device:
   ```bash
   adb push build-android/opensc-install/arm64-v8a/bin/opensc-tool \
            /data/local/tmp/
   adb shell chmod 755 /data/local/tmp/opensc-tool
   ```
3. Connect USB smart card reader via OTG adapter
4. Test:
   ```bash
   adb shell /data/local/tmp/opensc-tool --list-readers
   ```

### On Android Emulator

1. Build for `x86_64` (for 64-bit emulator)
2. Push and test as above

## Common Issues

### "ANDROID_NDK_ROOT is not set"

```bash
export ANDROID_NDK_ROOT=/Users/you/Library/Android/sdk/ndk/25.2.9519653
# or
export ANDROID_NDK_ROOT=/home/you/android-ndk-r25c
```

### "libusb not found for arm64-v8a"

Build libusb first:
```bash
./build-libusb-android.sh arm64-v8a
```

### "configure: command not found"

Run bootstrap to generate configure script:
```bash
./bootstrap
```

### "USB device not found" in Android app

1. Check USB OTG support on device
2. Request USB permission in app
3. Grant USB permission when prompted
4. Verify reader is CCID-compliant

## Clean Build

Remove all build artifacts:

```bash
./clean-android-build.sh
```

Or manually:

```bash
rm -rf build-android/
```

## Architecture Selection Guide

| Device Type | Architecture | Priority |
|-------------|-------------|----------|
| Modern phones (2018+) | arm64-v8a | High |
| Older phones | armeabi-v7a | Medium |
| Android emulator (64-bit) | x86_64 | Low |
| Android emulator (32-bit) | x86 | Low |

**Recommendation**: Build for `arm64-v8a` and `armeabi-v7a` to cover most real devices.

## File Sizes (Approximate)

After building and stripping:
- `libopensc.so`: ~500 KB - 1 MB
- `opensc-pkcs11.so`: ~600 KB - 1.2 MB
- `libusb-1.0.so`: ~50-100 KB
- Total per architecture: ~2-3 MB

## Next Steps

1. **Read full documentation**: [ANDROID_BUILD.md](ANDROID_BUILD.md)
2. **Test on device**: Connect a CCID reader and verify communication
3. **Integrate into app**: Create JNI wrappers or use command-line tools
4. **Handle permissions**: Implement USB permission request flow
5. **Add error handling**: Handle USB disconnections, permission denials, etc.

## Support

For issues:
1. Check [ANDROID_BUILD.md](ANDROID_BUILD.md) troubleshooting section
2. Review build logs in `build-android/` subdirectories
3. Open issue at: https://github.com/OpenSC/OpenSC/issues

## Key Features Enabled

✓ Direct USB CCID communication via libusb
✓ No PC/SC dependency
✓ Works with USB OTG on Android devices
✓ Supports all CCID-compliant smart card readers
✓ Full OpenSC functionality (PKCS#11, PKCS#15, etc.)

## Key Features Disabled

✗ PC/SC (not available on Android)
✗ CryptoTokenKit (macOS only)
✗ CT-API (legacy, not needed)
✗ Desktop notifications
✗ Man pages and documentation (reduces build size)

## Build Time

Approximate build times on modern hardware:
- libusb (all architectures): 5-10 minutes
- OpenSC (all architectures): 15-30 minutes
- Total: 20-40 minutes

Single architecture builds are proportionally faster.

## Minimum Requirements

- **Android Device**: Android 5.0 (API 21) or higher
- **USB OTG**: Required for USB smart card reader connection
- **Build Host**: macOS or Linux with Android NDK
- **Disk Space**: ~500 MB for build artifacts
- **RAM**: 4 GB recommended for parallel builds
