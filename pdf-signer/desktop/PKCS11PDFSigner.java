package org.opensc.pdfsigner;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.security.KeyStore;
import java.security.MessageDigest;
import java.security.Provider;
import java.security.Security;
import java.security.Signature;
import java.security.cert.Certificate;
import java.security.cert.X509Certificate;
import java.util.Calendar;

import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.pdmodel.interactive.digitalsignature.PDSignature;
import org.apache.pdfbox.pdmodel.interactive.digitalsignature.SignatureOptions;
import org.bouncycastle.cert.jcajce.JcaCertStore;
import org.bouncycastle.cms.CMSSignedData;
import org.bouncycastle.cms.CMSSignedDataGenerator;
import org.bouncycastle.cms.CMSTypedData;
import org.bouncycastle.cms.jcajce.JcaSignerInfoGeneratorBuilder;
import org.bouncycastle.operator.ContentSigner;
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder;
import org.bouncycastle.operator.jcajce.JcaDigestCalculatorProviderBuilder;

/**
 * PDF Signer using PKCS#11 hardware tokens (smart cards, USB crypto tokens)
 * with Apache PDFBox and BouncyCastle
 *
 * This implementation works with OpenSC PKCS#11 middleware for accessing
 * physical digital signature tokens.
 */
public class PKCS11PDFSigner extends CreateSignatureBase {

    /**
     * Constructor
     *
     * @param keystore PKCS#11 KeyStore
     * @param pin PIN for accessing the private key
     */
    public PKCS11PDFSigner(KeyStore keystore, char[] pin) throws Exception {
        super(keystore, pin);
    }

    /**
     * Sign a PDF document
     *
     * @param inputFile Input PDF file
     * @param outputFile Output signed PDF file
     * @param signatureName Name to display on signature
     * @param signatureLocation Location where signature was created
     * @param signatureReason Reason for signing
     * @throws Exception
     */
    public void signPDF(File inputFile, File outputFile,
                       String signatureName, String signatureLocation,
                       String signatureReason) throws Exception {

        if (!inputFile.exists()) {
            throw new IOException("Input file does not exist: " + inputFile);
        }

        PDDocument doc = null;
        FileOutputStream fos = null;

        try {
            doc = PDDocument.load(inputFile);

            // Create signature dictionary
            PDSignature signature = new PDSignature();
            signature.setFilter(PDSignature.FILTER_ADOBE_PPKLITE);
            signature.setSubFilter(PDSignature.SUBFILTER_ADBE_PKCS7_DETACHED);
            signature.setName(signatureName);
            signature.setLocation(signatureLocation);
            signature.setReason(signatureReason);
            signature.setSignDate(Calendar.getInstance());

            // Register signature dictionary and sign interface
            doc.addSignature(signature, this);

            // Write incremental (only append to original PDF)
            fos = new FileOutputStream(outputFile);
            doc.saveIncremental(fos);

            System.out.println("PDF signed successfully!");
            System.out.println("Output: " + outputFile.getAbsolutePath());

        } finally {
            if (doc != null) {
                doc.close();
            }
            if (fos != null) {
                fos.close();
            }
        }
    }

    /**
     * SignatureInterface implementation - this is where the actual signing happens
     *
     * @param content The PDF content to be signed
     * @return The signature bytes (CMS/PKCS#7)
     */
    @Override
    public byte[] sign(InputStream content) throws IOException {
        try {
            // Read content into memory for signing
            byte[] buffer = new byte[8192];
            int bytesRead;
            MessageDigest digest = MessageDigest.getInstance("SHA-256");

            while ((bytesRead = content.read(buffer)) != -1) {
                digest.update(buffer, 0, bytesRead);
            }

            // Create CMS signed data
            CMSSignedDataGenerator gen = new CMSSignedDataGenerator();

            X509Certificate cert = (X509Certificate) certificateChain[0];

            // Use the private key from the hardware token
            ContentSigner signer = new JcaContentSignerBuilder("SHA256withRSA")
                    .build(privateKey);

            gen.addSignerInfoGenerator(
                new JcaSignerInfoGeneratorBuilder(
                    new JcaDigestCalculatorProviderBuilder().build())
                .build(signer, cert));

            // Add certificate chain
            gen.addCertificates(new JcaCertStore(java.util.Arrays.asList(certificateChain)));

            // Generate the signature
            CMSTypedData cmsData = new CMSProcessableInputStream(content);
            CMSSignedData signedData = gen.generate(cmsData, false);

            return signedData.getEncoded();

        } catch (Exception e) {
            throw new IOException("Signature generation failed", e);
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

    /**
     * Main method - command line interface
     *
     * Usage: java PKCS11PDFSigner <pkcs11-config> <pin> <input.pdf> <output.pdf> [name] [location] [reason]
     */
    public static void main(String[] args) {
        if (args.length < 4) {
            System.err.println("Usage: java PKCS11PDFSigner <pkcs11-config> <pin> <input.pdf> <output.pdf> [name] [location] [reason]");
            System.err.println();
            System.err.println("Example:");
            System.err.println("  java PKCS11PDFSigner opensc-pkcs11.cfg 1234 document.pdf signed.pdf \"John Doe\" \"Office\" \"Approval\"");
            System.exit(1);
        }

        String pkcs11ConfigPath = args[0];
        String pin = args[1];
        String inputPath = args[2];
        String outputPath = args[3];
        String name = args.length > 4 ? args[4] : "Digital Signature";
        String location = args.length > 5 ? args[5] : "OpenSC";
        String reason = args.length > 6 ? args[6] : "Document Approval";

        try {
            System.out.println("OpenSC PDF Signer with PKCS#11 Hardware Token");
            System.out.println("==============================================");
            System.out.println();

            // Initialize PKCS#11 provider
            System.out.println("Loading PKCS#11 configuration: " + pkcs11ConfigPath);
            Provider pkcs11Provider;

            // Support both old and new Java versions
            try {
                // Java 9+ method
                pkcs11Provider = Security.getProvider("SunPKCS11");
                pkcs11Provider = pkcs11Provider.configure(pkcs11ConfigPath);
            } catch (Exception e) {
                // Java 8 and older method
                pkcs11Provider = new sun.security.pkcs11.SunPKCS11(pkcs11ConfigPath);
            }

            Security.addProvider(pkcs11Provider);
            System.out.println("PKCS#11 provider loaded: " + pkcs11Provider.getName());

            // Load keystore from hardware token
            System.out.println("Loading keystore from hardware token...");
            KeyStore keystore = KeyStore.getInstance("PKCS11", pkcs11Provider);
            keystore.load(null, pin.toCharArray());

            System.out.println("Keystore loaded successfully");
            System.out.println();

            // Create signer
            PKCS11PDFSigner signer = new PKCS11PDFSigner(keystore, pin.toCharArray());

            // Sign the PDF
            System.out.println("Signing PDF...");
            System.out.println("  Input: " + inputPath);
            System.out.println("  Output: " + outputPath);
            System.out.println("  Signer: " + name);
            System.out.println("  Location: " + location);
            System.out.println("  Reason: " + reason);
            System.out.println();

            File inputFile = new File(inputPath);
            File outputFile = new File(outputPath);

            signer.signPDF(inputFile, outputFile, name, location, reason);

            System.out.println();
            System.out.println("SUCCESS: PDF signed with hardware token!");

        } catch (Exception e) {
            System.err.println("ERROR: Failed to sign PDF");
            e.printStackTrace();
            System.exit(1);
        }
    }
}
