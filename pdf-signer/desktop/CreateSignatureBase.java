package org.opensc.pdfsigner;

import java.io.IOException;
import java.io.InputStream;
import java.security.GeneralSecurityException;
import java.security.KeyStore;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;
import java.security.PrivateKey;
import java.security.UnrecoverableKeyException;
import java.security.cert.Certificate;
import java.security.cert.CertificateException;
import java.security.cert.X509Certificate;
import java.util.Arrays;
import java.util.Enumeration;

import org.apache.pdfbox.pdmodel.interactive.digitalsignature.SignatureInterface;

/**
 * Base class for creating PDF signatures with hardware tokens via PKCS#11
 * Based on Apache PDFBox examples
 */
public abstract class CreateSignatureBase implements SignatureInterface {

    protected PrivateKey privateKey;
    protected Certificate[] certificateChain;

    /**
     * Initialize the signature base with a PKCS#11 keystore
     *
     * @param keystore The KeyStore containing the signing certificate
     * @param pin The PIN for accessing the private key
     * @throws KeyStoreException
     * @throws UnrecoverableKeyException
     * @throws NoSuchAlgorithmException
     */
    public CreateSignatureBase(KeyStore keystore, char[] pin)
            throws KeyStoreException, UnrecoverableKeyException, NoSuchAlgorithmException {

        // Find the first certificate with a private key
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
            throw new KeyStoreException("No certificate with private key found in keystore");
        }

        // Get private key
        privateKey = (PrivateKey) keystore.getKey(alias, pin);

        // Get certificate chain
        certificateChain = keystore.getCertificateChain(alias);

        if (certificateChain == null || certificateChain.length == 0) {
            throw new KeyStoreException("No certificate chain found for alias: " + alias);
        }

        System.out.println("Using certificate: " + alias);
        if (certificateChain[0] instanceof X509Certificate) {
            X509Certificate cert = (X509Certificate) certificateChain[0];
            System.out.println("  Subject: " + cert.getSubjectX500Principal());
            System.out.println("  Issuer: " + cert.getIssuerX500Principal());
            System.out.println("  Serial: " + cert.getSerialNumber());
            System.out.println("  Valid until: " + cert.getNotAfter());
        }
    }

    /**
     * Get the certificate chain
     */
    public Certificate[] getCertificateChain() {
        return certificateChain;
    }

    /**
     * Get the private key
     */
    public PrivateKey getPrivateKey() {
        return privateKey;
    }
}
