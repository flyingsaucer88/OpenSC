# OpenSC Android Integration Layer

This directory contains the Android USB host API integration layer for OpenSC, enabling seamless USB CCID smart card reader access on Android devices.

## Components

### Native Code (C/JNI)

1. **[usb_android.c](usb_android.c)** - USB Host API integration
   - Bridges Android USB API with libusb
   - Handles USB device enumeration
   - Manages USB permissions and file descriptors
   - CCID device detection

2. **[opensc_android.c](opensc_android.c)** - OpenSC JNI wrapper
   - Native interface to OpenSC library
   - Smart card reader operations
   - Card detection and ATR retrieval
   - PKCS#15 PIN verification

### Java Code

1. **[UsbManager.java](UsbManager.java)** - USB device management
   - High-level USB device handling
   - CCID reader detection
   - Permission management
   - Device lifecycle management

2. **[UsbDeviceInfo.java](UsbDeviceInfo.java)** - Device information
   - Data class for USB device details
   - VID/PID, bus, address information

3. **[OpenSCBridge.java](OpenSCBridge.java)** - Main OpenSC interface
   - Primary API for Android apps
   - Initializes USB and OpenSC subsystems
   - Provides smart card operations
   - Reader enumeration and card detection

### Build Files

1. **[Android.mk](Android.mk)** - NDK build system (ndk-build)
2. **[CMakeLists.txt](CMakeLists.txt)** - CMake build system

## Prerequisites

Before using this integration layer, you must:

1. Build OpenSSL for Android
   ```bash
   ./build-openssl-android.sh all
   ```

2. Build libusb for Android
   ```bash
   ./build-libusb-android.sh all
   ```

3. Build OpenSC for Android
   ```bash
   ./build-opensc-android.sh all
   ```

This creates the required libraries in `build-android/`.

## Integration into Android App

### Step 1: Copy Files to Your Project

```
your-android-project/
├── app/src/main/
│   ├── java/org/opensc/android/
│   │   ├── UsbManager.java
│   │   ├── UsbDeviceInfo.java
│   │   └── OpenSCBridge.java
│   │
│   ├── cpp/  (or jni/)
│   │   ├── usb_android.c
│   │   ├── opensc_android.c
│   │   └── CMakeLists.txt (or Android.mk)
│   │
│   └── jniLibs/
│       ├── arm64-v8a/
│       │   ├── libcrypto.so
│       │   ├── libssl.so
│       │   ├── libusb-1.0.so
│       │   ├── libopensc.so
│       │   └── opensc-pkcs11.so
│       └── armeabi-v7a/
│           └── ... (same files)
```

### Step 2: Copy Libraries

```bash
# For ARM64 (most common)
cp build-android/openssl-install/arm64-v8a/lib/libcrypto.so \
   your-app/src/main/jniLibs/arm64-v8a/

cp build-android/openssl-install/arm64-v8a/lib/libssl.so \
   your-app/src/main/jniLibs/arm64-v8a/

cp build-android/install/arm64-v8a/lib/libusb-1.0.so \
   your-app/src/main/jniLibs/arm64-v8a/

cp build-android/opensc-install/arm64-v8a/lib/libopensc.so \
   your-app/src/main/jniLibs/arm64-v8a/

cp build-android/opensc-install/arm64-v8a/lib/opensc-pkcs11.so \
   your-app/src/main/jniLibs/arm64-v8a/

# Repeat for other ABIs as needed
```

### Step 3: Update AndroidManifest.xml

```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="your.package.name">

    <!-- USB host support -->
    <uses-feature android:name="android.hardware.usb.host" />

    <!-- USB permission -->
    <uses-permission android:name="android.hardware.usb.host" />

    <application ...>
        <activity ...>
            <!-- USB device intent filter -->
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

### Step 4: Create USB Device Filter

Create `res/xml/device_filter.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <!-- CCID class devices -->
    <usb-device class="11" />

    <!-- Or specific vendor/product IDs -->
    <!-- Example: ACR122U NFC Reader -->
    <usb-device vendor-id="1839" product-id="8704" />
</resources>
```

### Step 5: Configure CMake in app/build.gradle

```gradle
android {
    ...
    defaultConfig {
        ...
        externalNativeBuild {
            cmake {
                cppFlags ""
                arguments "-DANDROID_ABI=arm64-v8a"
            }
        }
        ndk {
            abiFilters 'arm64-v8a', 'armeabi-v7a'
        }
    }

    externalNativeBuild {
        cmake {
            path "src/main/cpp/CMakeLists.txt"
            version "3.10.2"
        }
    }
}
```

## Usage Example

### Basic Usage

```java
package your.package.name;

import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbManager;
import android.os.Bundle;
import android.util.Log;

import org.opensc.android.OpenSCBridge;

import java.util.List;

public class MainActivity extends Activity {
    private static final String TAG = "OpenSC-Demo";
    private static final String ACTION_USB_PERMISSION =
        "your.package.name.USB_PERMISSION";

    private OpenSCBridge opensc;
    private UsbManager usbManager;
    private PendingIntent permissionIntent;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        // Initialize OpenSC
        opensc = new OpenSCBridge(this);
        if (!opensc.initialize()) {
            Log.e(TAG, "Failed to initialize OpenSC");
            finish();
            return;
        }

        // Setup USB manager
        usbManager = (UsbManager) getSystemService(Context.USB_SERVICE);
        permissionIntent = PendingIntent.getBroadcast(
            this, 0, new Intent(ACTION_USB_PERMISSION), 0);

        // Register USB permission receiver
        IntentFilter filter = new IntentFilter(ACTION_USB_PERMISSION);
        registerReceiver(usbReceiver, filter);

        // Check for CCID readers
        checkForReaders();
    }

    private void checkForReaders() {
        List<UsbDevice> ccidDevices = opensc.getCCIDReaders();

        if (ccidDevices.isEmpty()) {
            Log.i(TAG, "No CCID readers found");
            return;
        }

        for (UsbDevice device : ccidDevices) {
            Log.i(TAG, "Found CCID reader: " +
                  opensc.getUsbManager().getDeviceInfo(device));

            // Request permission if needed
            if (!usbManager.hasPermission(device)) {
                Log.i(TAG, "Requesting USB permission");
                usbManager.requestPermission(device, permissionIntent);
            } else {
                // Permission already granted
                openReader(device);
            }
        }
    }

    private void openReader(UsbDevice device) {
        if (opensc.openReader(device)) {
            Log.i(TAG, "Reader opened successfully");

            // List readers
            String[] readers = opensc.listReaders();
            for (int i = 0; i < readers.length; i++) {
                Log.i(TAG, "Reader " + i + ": " + readers[i]);

                // Check for card
                if (opensc.isCardPresent(i)) {
                    String atr = opensc.getCardATR(i);
                    String info = opensc.getCardInfo(i);

                    Log.i(TAG, "Card detected!");
                    Log.i(TAG, "ATR: " + atr);
                    Log.i(TAG, "Info: " + info);
                }
            }
        } else {
            Log.e(TAG, "Failed to open reader");
        }
    }

    private final BroadcastReceiver usbReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            String action = intent.getAction();

            if (ACTION_USB_PERMISSION.equals(action)) {
                synchronized (this) {
                    UsbDevice device = intent.getParcelableExtra(
                        UsbManager.EXTRA_DEVICE);

                    if (intent.getBooleanExtra(
                            UsbManager.EXTRA_PERMISSION_GRANTED, false)) {
                        if (device != null) {
                            Log.i(TAG, "USB permission granted");
                            openReader(device);
                        }
                    } else {
                        Log.w(TAG, "USB permission denied");
                    }
                }
            }
        }
    };

    @Override
    protected void onDestroy() {
        super.onDestroy();

        unregisterReceiver(usbReceiver);

        if (opensc != null) {
            opensc.cleanup();
        }
    }
}
```

## API Reference

### OpenSCBridge

| Method | Description |
|--------|-------------|
| `initialize()` | Initialize OpenSC and USB subsystem |
| `cleanup()` | Release all resources |
| `getCCIDReaders()` | Get list of CCID smart card readers |
| `openReader(device)` | Open CCID reader device |
| `closeReader(device)` | Close CCID reader device |
| `listReaders()` | List connected readers |
| `isCardPresent(index)` | Check if card is in reader |
| `getCardATR(index)` | Get card ATR |
| `getCardInfo(index)` | Get card information |

### UsbManager

| Method | Description |
|--------|-------------|
| `getDevices()` | Get all USB devices |
| `getCCIDDevices()` | Get only CCID devices |
| `isCCIDDevice(device)` | Check if device is CCID |
| `openDevice(device)` | Open USB device |
| `closeDevice(device)` | Close USB device |
| `getDeviceInfo(device)` | Get device information string |

## Supported CCID Readers

This integration supports all CCID-compliant USB smart card readers:

- ✓ Generic CCID readers (USB interface class 0x0B)
- ✓ ACR122U NFC reader
- ✓ Gemalto readers
- ✓ Identiv/SCM readers
- ✓ HID Omnikey readers
- ✓ YubiKey (in CCID mode)

## Troubleshooting

### Library Not Found
Ensure all .so files are in jniLibs/[ABI]/ and loaded in correct order:
```java
System.loadLibrary("crypto");
System.loadLibrary("ssl");
System.loadLibrary("usb-1.0");
System.loadLibrary("opensc");
System.loadLibrary("usb-android");
```

### USB Permission Denied
- Check AndroidManifest.xml has USB permissions
- Request permission using UsbManager.requestPermission()
- Handle permission result in BroadcastReceiver

### No Readers Found
- Verify USB OTG cable/adapter
- Check device supports USB host mode
- Ensure reader is CCID-compliant
- Check logcat for errors

### Card Not Detected
- Ensure card is properly inserted
- Try removing and reinserting card
- Check reader LED indicators
- Verify reader power via USB

## License

This integration layer is part of OpenSC and is licensed under LGPL 2.1+.

## Support

For issues and questions:
- OpenSC Issues: https://github.com/OpenSC/OpenSC/issues
- Documentation: See main Android build documentation in parent directory
