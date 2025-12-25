package org.opensc.android.pdfsigner;

import android.content.Context;
import android.hardware.usb.UsbDevice;
import android.util.Log;

import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.pdmodel.interactive.digitalsignature.PDSignature;
import org.apache.pdfbox.pdmodel.interactive.digitalsignature.SignatureInterface;
import org.bouncycastle.cert.jcajce.JcaCertStore;
import org.bouncycastle.cms.CMSSignedData;
import org.bouncycastle.cms.CMSSignedDataGenerator;
import org.bouncycastle.cms.CMSTypedData;
import org.bouncycastle.cms.jcajce.JcaSignerInfoGeneratorBuilder;
import org.bouncycastle.operator.ContentSigner;
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder;
import org.bouncycastle.operator.jcajce.JcaDigestCalculatorProviderBuilder;
import org.opensc.android.OpenSCBridge;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.security.KeyStore;
import java.security.MessageDigest;
import java.security.PrivateKey;
import java.security.Provider;
import java.security.Security;
import java.security.cert.Certificate;
import java.security.cert.X509Certificate;
import java.util.Calendar;
import java.util.Enumeration;

/**
 * Android PDF Signer using OpenSC middleware and hardware tokens
 *
 * This class integrates with the OpenSC Android USB bridge to sign PDFs
 * using physical smart cards or USB crypto tokens connected via USB OTG.
 */
public class AndroidPDFSigner implements SignatureInterface {

    private static final String TAG = "AndroidPDFSigner";

    private Context context;
    private OpenSCBridge opensc;
    private KeyStore keystore;
    private PrivateKey privateKey;
    private Certificate[] certificateChain;
    private String pin;

    /**
     * Constructor
     *
     * @param context Android application context
     */
    public AndroidPDFSigner(Context context) {
        this.context = context;
        this.opensc = new OpenSCBridge(context);
    }

    /**
     * Initialize the signer with a USB device and PIN
     *
     * @param usbDevice The USB smart card reader device
     * @param pin The PIN for the smart card
     * @return true if initialization successful
     */
    public boolean initialize(UsbDevice usbDevice, String pin) {
        try {
            this.pin = pin;

            // Initialize OpenSC
            if (!opensc.initialize()) {
                Log.e(TAG, "Failed to initialize OpenSC");
                return false;
            }

            // Open the USB reader
            if (!opensc.openReader(usbDevice)) {
                Log.e(TAG, "Failed to open USB reader");
                return false;
            }

            // Initialize PKCS#11 provider
            String pkcs11Config = createPKCS11Config();
            Provider pkcs11Provider;

            try {
                // Try Java 9+ method first
                pkcs11Provider = Security.getProvider("SunPKCS11");
                pkcs11Provider = pkcs11Provider.configure(pkcs11Config);
            } catch (Exception e) {
                // Fallback to older method
                pkcs11Provider = new sun.security.pkcs11.SunPKCS11(
                    new java.io.ByteArrayInputStream(pkcs11Config.getBytes("UTF-8"))
                );
            }

            Security.addProvider(pkcs11Provider);
            Log.i(TAG, "PKCS#11 provider added: " + pkcs11Provider.getName());

            // Load keystore
            keystore = KeyStore.getInstance("PKCS11", pkcs11Provider);
            keystore.load(null, pin.toCharArray());

            // Find certificate with private key
            Enumeration<String> aliases = keystore.aliases();
            String alias = null;

            while (aliases.hasMoreElements()) {
                String currentAlias = aliases.nextElement();
                if (keystore.isKeyEntry(currentAlias)) {
                    alias = currentAlias;
                    break;
                }
            }

            if (alias == null) {
                Log.e(TAG, "No certificate with private key found");
                return false;
            }

            // Get private key and certificate chain
            privateKey = (PrivateKey) keystore.getKey(alias, pin.toCharArray());
            certificateChain = keystore.getCertificateChain(alias);

            if (certificateChain == null || certificateChain.length == 0) {
                Log.e(TAG, "No certificate chain found");
                return false;
            }

            Log.i(TAG, "Signer initialized successfully with certificate: " + alias);
            if (certificateChain[0] instanceof X509Certificate) {
                X509Certificate cert = (X509Certificate) certificateChain[0];
                Log.i(TAG, "Subject: " + cert.getSubjectX500Principal());
                Log.i(TAG, "Issuer: " + cert.getIssuerX500Principal());
            }

            return true;

        } catch (Exception e) {
            Log.e(TAG, "Initialization failed", e);
            return false;
        }
    }

    /**
     * Create PKCS#11 configuration for Android
     */
    private String createPKCS11Config() {
        // Get the native library path
        String libPath = context.getApplicationInfo().nativeLibraryDir + "/libopensc-pkcs11.so";

        return "name = OpenSC-Android\n" +
               "library = " + libPath + "\n" +
               "description = OpenSC PKCS#11 for Android\n" +
               "slotListIndex = 0\n";
    }

    /**
     * Sign a PDF file
     *
     * @param inputFile Input PDF file
     * @param outputFile Output signed PDF file
     * @param signerName Name to display on signature
     * @param location Location where signature was created
     * @param reason Reason for signing
     * @return true if signing successful
     */
    public boolean signPDF(File inputFile, File outputFile,
                          String signerName, String location, String reason) {

        if (privateKey == null || certificateChain == null) {
            Log.e(TAG, "Signer not initialized");
            return false;
        }

        PDDocument doc = null;
        FileOutputStream fos = null;

        try {
            Log.i(TAG, "Loading PDF: " + inputFile.getAbsolutePath());
            doc = PDDocument.load(inputFile);

            // Create signature dictionary
            PDSignature signature = new PDSignature();
            signature.setFilter(PDSignature.FILTER_ADOBE_PPKLITE);
            signature.setSubFilter(PDSignature.SUBFILTER_ADBE_PKCS7_DETACHED);
            signature.setName(signerName);
            signature.setLocation(location);
            signature.setReason(reason);
            signature.setSignDate(Calendar.getInstance());

            // Register signature
            doc.addSignature(signature, this);

            // Save incrementally
            Log.i(TAG, "Signing PDF...");
            fos = new FileOutputStream(outputFile);
            doc.saveIncremental(fos);

            Log.i(TAG, "PDF signed successfully: " + outputFile.getAbsolutePath());
            return true;

        } catch (Exception e) {
            Log.e(TAG, "Failed to sign PDF", e);
            return false;

        } finally {
            try {
                if (doc != null) doc.close();
                if (fos != null) fos.close();
            } catch (IOException e) {
                Log.e(TAG, "Error closing resources", e);
            }
        }
    }

    /**
     * SignatureInterface implementation - performs actual signing
     */
    @Override
    public byte[] sign(InputStream content) throws IOException {
        try {
            Log.d(TAG, "Generating signature...");

            // Create CMS signed data generator
            CMSSignedDataGenerator gen = new CMSSignedDataGenerator();

            X509Certificate cert = (X509Certificate) certificateChain[0];

            // Create content signer using hardware token private key
            ContentSigner signer = new JcaContentSignerBuilder("SHA256withRSA")
                    .build(privateKey);

            gen.addSignerInfoGenerator(
                new JcaSignerInfoGeneratorBuilder(
                    new JcaDigestCalculatorProviderBuilder().build())
                .build(signer, cert));

            // Add certificate chain
            gen.addCertificates(new JcaCertStore(java.util.Arrays.asList(certificateChain)));

            // Generate signature
            CMSTypedData cmsData = new CMSProcessableInputStream(content);
            CMSSignedData signedData = gen.generate(cmsData, false);

            Log.d(TAG, "Signature generated successfully");
            return signedData.getEncoded();

        } catch (Exception e) {
            Log.e(TAG, "Signature generation failed", e);
            throw new IOException("Signature generation failed", e);
        }
    }

    /**
     * Cleanup resources
     */
    public void cleanup() {
        if (opensc != null) {
            opensc.cleanup();
        }
    }

    /**
     * Helper class for CMS signed data
     */
    private static class CMSProcessableInputStream implements CMSTypedData {
        private InputStream in;
        private final org.bouncycastle.asn1.ASN1ObjectIdentifier contentType;

        CMSProcessableInputStream(InputStream is) {
            this.in = is;
            this.contentType = new org.bouncycastle.asn1.ASN1ObjectIdentifier(
                org.bouncycastle.asn1.pkcs.PKCSObjectIdentifiers.data.getId());
        }

        @Override
        public Object getContent() {
            return in;
        }

        @Override
        public void write(java.io.OutputStream out) throws IOException {
            byte[] buffer = new byte[8192];
            int read;
            while ((read = in.read(buffer)) != -1) {
                out.write(buffer, 0, read);
            }
            in.close();
        }

        @Override
        public org.bouncycastle.asn1.ASN1ObjectIdentifier getContentType() {
            return contentType;
        }
    }
}
