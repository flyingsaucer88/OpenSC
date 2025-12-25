# PDF Signer Quick Start Guide

Get started signing PDFs with your hardware token in 5 minutes.

## Desktop Quick Start

### 1. Build

```bash
cd pdf-signer/desktop
mvn clean package
```

### 2. Configure

Edit `opensc-pkcs11.cfg` with your OpenSC library path:

```bash
# Linux
library = /usr/lib/x86_64-linux-gnu/opensc-pkcs11.so

# macOS (Intel)
library = /usr/local/lib/opensc-pkcs11.so

# macOS (Apple Silicon)
library = /opt/homebrew/lib/opensc-pkcs11.so
```

### 3. Test Your Smart Card

```bash
# List available readers
opensc-tool --list-readers

# List objects on card
pkcs11-tool --list-objects

# Test PIN
pkcs11-tool --login --pin 1234 --test
```

### 4. Sign a PDF

```bash
java -jar target/pkcs11-pdf-signer-1.0.0-jar-with-dependencies.jar \
    ../opensc-pkcs11.cfg \
    1234 \
    document.pdf \
    signed.pdf
```

Replace `1234` with your actual PIN.

## Android Quick Start

### 1. Add to Your Project

In `settings.gradle`:
```gradle
include ':pdf-signer'
project(':pdf-signer').projectDir = new File('path/to/pdf-signer/android')
```

In `app/build.gradle`:
```gradle
dependencies {
    implementation project(':pdf-signer')
    implementation project(':opensc-android')
}
```

### 2. Add Permissions

In `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-feature android:name="android.hardware.usb.host" />
```

### 3. Use in Your Activity

```java
AndroidPDFSigner signer = new AndroidPDFSigner(this);

// Initialize with USB smart card reader
signer.initialize(usbDevice, "1234");

// Sign PDF
File input = new File("/sdcard/Documents/doc.pdf");
File output = new File("/sdcard/Documents/doc_signed.pdf");
signer.signPDF(input, output, "John Doe", "Office", "Approved");

// Cleanup
signer.cleanup();
```

## Common Commands

### Check OpenSC Installation

```bash
# Version
opensc-tool --version

# List readers
opensc-tool --list-readers

# Card info
opensc-tool --name
```

### List Certificates on Card

```bash
pkcs11-tool --list-objects --type cert
```

### Test PKCS#11 Provider

```bash
pkcs11-tool --module /usr/local/lib/opensc-pkcs11.so --test
```

### Verify Signed PDF

```bash
# Using pdfsig (Poppler)
pdfsig signed.pdf

# Using OpenSC tools
pkcs11-tool --verify --input signed.pdf
```

## Troubleshooting Quick Fixes

### Library Not Found
```bash
# Find OpenSC PKCS#11 library
find /usr -name "opensc-pkcs11.so" 2>/dev/null
find /opt -name "opensc-pkcs11.so" 2>/dev/null
```

### Smart Card Not Detected
```bash
# Check USB
lsusb | grep -i "smart\|card\|ccid"

# Check PC/SC daemon (if running)
systemctl status pcscd
```

### Wrong PIN
```bash
# Check PIN retry counter
pkcs15-tool --list-pins
```

### Java Issues
```bash
# Check Java version
java -version

# Should be Java 8 or higher
```

## Example Files

### Test PDF Creation

```bash
# Create a test PDF with LibreOffice
libreoffice --headless --convert-to pdf test.txt

# Or download a sample
wget https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf
```

### Batch Signing Script

```bash
#!/bin/bash
# sign-all.sh

CONFIG="../opensc-pkcs11.cfg"
PIN="1234"

for pdf in *.pdf; do
    echo "Signing: $pdf"
    java -jar signer.jar "$CONFIG" "$PIN" "$pdf" "signed_$pdf"
done
```

## Next Steps

- Read [README.md](README.md) for complete documentation
- Review [PDFSignerActivity.java](android/PDFSignerActivity.java) for Android example
- Check [PKCS11PDFSigner.java](desktop/PKCS11PDFSigner.java) for desktop implementation

## Support

Need help? Check:
- OpenSC Wiki: https://github.com/OpenSC/OpenSC/wiki
- PDFBox FAQ: https://pdfbox.apache.org/support.html
- Your card manufacturer documentation
