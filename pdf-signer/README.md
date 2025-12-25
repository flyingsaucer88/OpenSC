# OpenSC PDF Signer with PKCS#11 Hardware Tokens

This project provides complete PDF digital signature capabilities using physical smart cards and USB crypto tokens via OpenSC PKCS#11 middleware.

## Features

- ✅ **Hardware Token Support**: Sign PDFs using physical smart cards and USB crypto tokens
- ✅ **PKCS#11 Integration**: Full OpenSC PKCS#11 middleware support
- ✅ **Desktop & Android**: Cross-platform implementations
- ✅ **Apache PDFBox**: Industry-standard PDF manipulation
- ✅ **BouncyCastle**: Robust cryptographic operations (CMS/PKCS#7)
- ✅ **USB OTG Support**: Android devices with USB OTG can use hardware tokens
- ✅ **Standards Compliant**: Adobe-compatible digital signatures (PKCS#7 Detached)

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                 PDF Signer Application                  │
│           (Desktop Java / Android App)                  │
└─────────────────┬───────────────────────────────────────┘
                  │
                  ├──> Apache PDFBox (PDF manipulation)
                  ├──> BouncyCastle (CMS/PKCS#7 signatures)
                  │
┌─────────────────▼───────────────────────────────────────┐
│             Java Security Provider (PKCS#11)            │
└─────────────────┬───────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────┐
│         OpenSC PKCS#11 Middleware (opensc-pkcs11.so)    │
└─────────────────┬───────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────┐
│           USB Smart Card Reader (CCID)                  │
└─────────────────┬───────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────────┐
│         Physical Smart Card / USB Crypto Token          │
└─────────────────────────────────────────────────────────┘
```

## Project Structure

```
pdf-signer/
├── opensc-pkcs11.cfg              # Desktop PKCS#11 config
├── opensc-pkcs11-android.cfg      # Android PKCS#11 config
├── desktop/                       # Desktop Java implementation
│   ├── CreateSignatureBase.java   # Base class for signing
│   ├── PKCS11PDFSigner.java       # Main desktop signer
│   └── pom.xml                    # Maven build file
└── android/                       # Android implementation
    ├── AndroidPDFSigner.java      # Android signer class
    ├── PDFSignerActivity.java     # Example Activity
    └── build.gradle               # Android build file
```

## Prerequisites

### Desktop (Linux/macOS/Windows)

1. **Java JDK 8+**
   ```bash
   java -version
   ```

2. **OpenSC** installed and working
   ```bash
   # Linux
   sudo apt-get install opensc

   # macOS
   brew install opensc

   # Windows
   # Download from https://github.com/OpenSC/OpenSC/releases
   ```

3. **Maven** (for building)
   ```bash
   mvn --version
   ```

4. **Smart Card Reader** (CCID-compatible)

### Android

1. **Android device with USB OTG support**
2. **USB OTG cable/adapter**
3. **Your OpenSC Android build** from the main OpenSC project
4. **Android Studio** or Gradle for building

## Desktop Usage

### 1. Configure PKCS#11

Edit `opensc-pkcs11.cfg` to point to your OpenSC PKCS#11 library:

```
name = OpenSC
library = /usr/local/lib/opensc-pkcs11.so  # Adjust path for your system
```

**Common library paths:**
- **Linux**: `/usr/lib/x86_64-linux-gnu/opensc-pkcs11.so`
- **macOS**: `/usr/local/lib/opensc-pkcs11.so` or `/opt/homebrew/lib/opensc-pkcs11.so`
- **Windows**: `C:\Program Files\OpenSC Project\OpenSC\pkcs11\opensc-pkcs11.dll`

### 2. Build the Desktop Signer

```bash
cd desktop/
mvn clean package
```

This creates `target/pkcs11-pdf-signer-1.0.0-jar-with-dependencies.jar`

### 3. Sign a PDF

```bash
java -jar target/pkcs11-pdf-signer-1.0.0-jar-with-dependencies.jar \
    ../opensc-pkcs11.cfg \
    1234 \
    input.pdf \
    output_signed.pdf \
    "John Doe" \
    "Office" \
    "Document Approval"
```

**Arguments:**
1. PKCS#11 configuration file
2. Smart card PIN
3. Input PDF file
4. Output signed PDF file
5. Signer name (optional, default: "Digital Signature")
6. Location (optional, default: "OpenSC")
7. Reason (optional, default: "Document Approval")

### Example Output

```
OpenSC PDF Signer with PKCS#11 Hardware Token
==============================================

Loading PKCS#11 configuration: opensc-pkcs11.cfg
PKCS#11 provider loaded: SunPKCS11-OpenSC
Loading keystore from hardware token...
Keystore loaded successfully

Using certificate: Digital Signature Certificate
  Subject: CN=John Doe, O=Example Corp
  Issuer: CN=Example CA, O=Example Corp
  Serial: 123456789
  Valid until: Tue Dec 31 23:59:59 UTC 2025

Signing PDF...
  Input: document.pdf
  Output: document_signed.pdf
  Signer: John Doe
  Location: Office
  Reason: Document Approval

PDF signed successfully!
Output: /path/to/document_signed.pdf

SUCCESS: PDF signed with hardware token!
```

## Android Usage

### 1. Integration into Your Android App

Add the PDF signer module to your Android project:

```gradle
dependencies {
    implementation project(':pdf-signer')
    implementation project(':opensc-android')
}
```

### 2. Add Permissions to AndroidManifest.xml

```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-feature android:name="android.hardware.usb.host" />
```

### 3. Use in Your Activity

```java
import org.opensc.android.pdfsigner.AndroidPDFSigner;
import org.opensc.android.OpenSCBridge;

public class MyActivity extends Activity {
    private AndroidPDFSigner pdfSigner;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        pdfSigner = new AndroidPDFSigner(this);
    }

    private void signPDF(UsbDevice smartCardReader, String pin) {
        // Initialize with smart card
        if (!pdfSigner.initialize(smartCardReader, pin)) {
            Log.e(TAG, "Failed to initialize");
            return;
        }

        // Sign PDF
        File input = new File("/sdcard/Documents/document.pdf");
        File output = new File("/sdcard/Documents/document_signed.pdf");

        boolean success = pdfSigner.signPDF(
            input, output,
            "John Doe",
            "Android Device",
            "Mobile Approval"
        );

        if (success) {
            Toast.makeText(this, "PDF signed!", Toast.LENGTH_SHORT).show();
        }
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        pdfSigner.cleanup();
    }
}
```

### 4. Complete Example Activity

See [PDFSignerActivity.java](android/PDFSignerActivity.java) for a complete working example with:
- USB device permission handling
- Smart card detection
- PIN input
- File selection
- Status updates

## Supported Hardware Tokens

This signer works with any PKCS#11 compatible smart card or USB crypto token:

- ✅ **YubiKey** (PIV mode)
- ✅ **Nitrokey**
- ✅ **SmartCard-HSM**
- ✅ **Gemalto/Thales IDPrime**
- ✅ **eToken** (Aladdin/SafeNet)
- ✅ **CAC** (Common Access Card)
- ✅ **PIV** cards
- ✅ **OpenPGP** smart cards
- ✅ **Java Card** based tokens
- ✅ Any CCID-compliant card with OpenSC driver

## Supported Smart Card Readers

Any CCID-compliant USB smart card reader:

- ACR122U NFC Reader
- Identiv/SCM readers
- Gemalto readers
- HID Omnikey readers
- Cherry SmartTerminal readers
- Reiner SCT readers

## Testing Your Signature

### Verify with Adobe Acrobat Reader

1. Open signed PDF in Adobe Acrobat Reader
2. Click on signature panel
3. Verify signature shows as "Signed and all signatures are valid"

### Verify with pdfsig (Poppler)

```bash
pdfsig document_signed.pdf
```

### Verify with OpenSSL

```bash
# Extract signature
pdftk document_signed.pdf dump_data output metadata.txt

# Verify with OpenSSL (requires extracting CMS)
openssl cms -verify -in signature.p7s -inform DER -CAfile ca-cert.pem
```

## Troubleshooting

### Desktop Issues

**Problem**: `PKCS11 provider not found`
```
Solution: Ensure OpenSC is installed and library path in config is correct
```

**Problem**: `No certificate found`
```
Solution:
- Verify smart card is inserted
- Check PIN is correct
- Run: pkcs11-tool --list-objects
```

**Problem**: `Cannot create signer: sun.security.pkcs11.P11Key$P11PrivateKey`
```
Solution: Ensure BouncyCastle provider is loaded (included in dependencies)
```

### Android Issues

**Problem**: `Failed to initialize OpenSC`
```
Solution:
- Verify USB OTG cable is working
- Check USB permissions granted
- Ensure opensc-pkcs11.so is in app's native library directory
```

**Problem**: `No CCID readers found`
```
Solution:
- Verify reader is CCID-compliant
- Check reader is powered via USB
- Try different USB OTG adapter
```

## Advanced Configuration

### Custom Signature Appearance

Modify `PDSignature` object before signing:

```java
signature.setContactInfo("contact@example.com");
signature.setLocation("New York, USA");
signature.setReason("Legal Approval");
```

### Timestamp Authority (TSA)

Add trusted timestamp to signature:

```java
// In PKCS11PDFSigner.java, add TSA support
// This requires additional configuration
```

### Multiple Signatures

Sign PDF multiple times for co-signing:

```java
// Each signature creates a new revision
signer1.signPDF(input, temp, "Signer 1", "NYC", "Approval");
signer2.signPDF(temp, output, "Signer 2", "LA", "Approval");
```

## Security Considerations

1. **PIN Protection**: Never hardcode PINs in your application
2. **Certificate Validation**: Verify certificate chain before signing
3. **Secure Storage**: Store signed PDFs securely
4. **Token Removal**: Always cleanup and close token connections
5. **Permission Control**: Use Android permissions properly for USB access

## API Reference

### Desktop: PKCS11PDFSigner

```java
public class PKCS11PDFSigner {
    // Constructor
    public PKCS11PDFSigner(KeyStore keystore, char[] pin)

    // Sign PDF
    public void signPDF(File input, File output,
                       String name, String location, String reason)
}
```

### Android: AndroidPDFSigner

```java
public class AndroidPDFSigner {
    // Constructor
    public AndroidPDFSigner(Context context)

    // Initialize with smart card
    public boolean initialize(UsbDevice device, String pin)

    // Sign PDF
    public boolean signPDF(File input, File output,
                          String name, String location, String reason)

    // Cleanup
    public void cleanup()
}
```

## Dependencies

### Desktop (Maven)
- Apache PDFBox 2.0.30
- BouncyCastle 1.70
- Java 8+

### Android (Gradle)
- PDFBox-Android 2.0.27.0
- BouncyCastle 1.70
- AndroidX
- OpenSC Android (your build)

## License

This project integrates with OpenSC which is licensed under LGPL 2.1+.

## References

- [Apache PDFBox](https://pdfbox.apache.org/)
- [BouncyCastle](https://www.bouncycastle.org/)
- [OpenSC Project](https://github.com/OpenSC/OpenSC)
- [PKCS#11 Specification](http://docs.oasis-open.org/pkcs11/pkcs11-base/v2.40/pkcs11-base-v2.40.html)

## Support

For issues related to:
- **PDF Signing**: Check Apache PDFBox documentation
- **OpenSC/PKCS#11**: See OpenSC GitHub issues
- **Android Integration**: Review your OpenSC Android build documentation

---

**Created for OpenSC Android Integration Project**
