package org.opensc.android.pdfsigner;

import android.Manifest;
import android.app.Activity;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbManager;
import android.os.Bundle;
import android.os.Environment;
import android.util.Log;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.TextView;
import android.widget.Toast;

import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import org.opensc.android.OpenSCBridge;

import java.io.File;
import java.util.List;

/**
 * Example Android Activity for signing PDFs with hardware tokens
 */
public class PDFSignerActivity extends Activity {

    private static final String TAG = "PDFSignerActivity";
    private static final String ACTION_USB_PERMISSION = "org.opensc.USB_PERMISSION";
    private static final int PERMISSION_REQUEST_CODE = 1;

    private AndroidPDFSigner pdfSigner;
    private OpenSCBridge opensc;
    private UsbManager usbManager;
    private PendingIntent permissionIntent;

    private TextView statusText;
    private EditText pinInput;
    private EditText inputFileEdit;
    private EditText outputFileEdit;
    private EditText signerNameEdit;
    private Button signButton;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_pdf_signer);

        // Initialize UI
        statusText = findViewById(R.id.statusText);
        pinInput = findViewById(R.id.pinInput);
        inputFileEdit = findViewById(R.id.inputFile);
        outputFileEdit = findViewById(R.id.outputFile);
        signerNameEdit = findViewById(R.id.signerName);
        signButton = findViewById(R.id.signButton);

        // Set default values
        File documentsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS);
        inputFileEdit.setText(new File(documentsDir, "document.pdf").getAbsolutePath());
        outputFileEdit.setText(new File(documentsDir, "document_signed.pdf").getAbsolutePath());
        signerNameEdit.setText("Digital Signature");

        // Initialize OpenSC and PDF signer
        opensc = new OpenSCBridge(this);
        pdfSigner = new AndroidPDFSigner(this);

        // Setup USB manager
        usbManager = (UsbManager) getSystemService(Context.USB_SERVICE);
        permissionIntent = PendingIntent.getBroadcast(
            this, 0, new Intent(ACTION_USB_PERMISSION),
            PendingIntent.FLAG_IMMUTABLE);

        // Register USB permission receiver
        IntentFilter filter = new IntentFilter(ACTION_USB_PERMISSION);
        registerReceiver(usbReceiver, filter);

        // Request storage permissions
        checkPermissions();

        // Sign button handler
        signButton.setOnClickListener(v -> checkForSmartCard());

        updateStatus("Ready. Please insert smart card reader.");
    }

    private void checkPermissions() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE)
                != PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE)
                != PackageManager.PERMISSION_GRANTED) {

            ActivityCompat.requestPermissions(this,
                new String[]{
                    Manifest.permission.READ_EXTERNAL_STORAGE,
                    Manifest.permission.WRITE_EXTERNAL_STORAGE
                },
                PERMISSION_REQUEST_CODE);
        }
    }

    private void checkForSmartCard() {
        updateStatus("Checking for smart card readers...");

        List<UsbDevice> ccidDevices = opensc.getCCIDReaders();

        if (ccidDevices.isEmpty()) {
            updateStatus("ERROR: No CCID readers found. Please connect a smart card reader.");
            Toast.makeText(this, "No smart card reader found", Toast.LENGTH_LONG).show();
            return;
        }

        UsbDevice device = ccidDevices.get(0);
        updateStatus("Found reader: " + device.getProductName());

        // Request USB permission if needed
        if (!usbManager.hasPermission(device)) {
            updateStatus("Requesting USB permission...");
            usbManager.requestPermission(device, permissionIntent);
        } else {
            // Already have permission
            initializeAndSign(device);
        }
    }

    private void initializeAndSign(UsbDevice device) {
        String pin = pinInput.getText().toString();

        if (pin.isEmpty()) {
            Toast.makeText(this, "Please enter PIN", Toast.LENGTH_SHORT).show();
            return;
        }

        updateStatus("Initializing smart card...");

        // Initialize in background thread
        new Thread(() -> {
            boolean initialized = pdfSigner.initialize(device, pin);

            runOnUiThread(() -> {
                if (!initialized) {
                    updateStatus("ERROR: Failed to initialize smart card");
                    Toast.makeText(this, "Smart card initialization failed", Toast.LENGTH_LONG).show();
                    return;
                }

                updateStatus("Smart card initialized. Signing PDF...");
                signPDF();
            });
        }).start();
    }

    private void signPDF() {
        String inputPath = inputFileEdit.getText().toString();
        String outputPath = outputFileEdit.getText().toString();
        String signerName = signerNameEdit.getText().toString();

        File inputFile = new File(inputPath);
        File outputFile = new File(outputPath);

        if (!inputFile.exists()) {
            updateStatus("ERROR: Input file not found: " + inputPath);
            Toast.makeText(this, "Input file not found", Toast.LENGTH_LONG).show();
            return;
        }

        // Sign in background thread
        new Thread(() -> {
            boolean success = pdfSigner.signPDF(
                inputFile, outputFile,
                signerName,
                "Android Device",
                "Document Approval"
            );

            runOnUiThread(() -> {
                if (success) {
                    updateStatus("SUCCESS: PDF signed!\nOutput: " + outputPath);
                    Toast.makeText(this, "PDF signed successfully!", Toast.LENGTH_LONG).show();
                } else {
                    updateStatus("ERROR: Failed to sign PDF");
                    Toast.makeText(this, "PDF signing failed", Toast.LENGTH_LONG).show();
                }
            });
        }).start();
    }

    private void updateStatus(String message) {
        Log.i(TAG, message);
        statusText.setText(message);
    }

    private final BroadcastReceiver usbReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            String action = intent.getAction();

            if (ACTION_USB_PERMISSION.equals(action)) {
                synchronized (this) {
                    UsbDevice device = intent.getParcelableExtra(UsbManager.EXTRA_DEVICE);

                    if (intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)) {
                        if (device != null) {
                            updateStatus("USB permission granted");
                            initializeAndSign(device);
                        }
                    } else {
                        updateStatus("ERROR: USB permission denied");
                        Toast.makeText(context, "USB permission denied", Toast.LENGTH_LONG).show();
                    }
                }
            }
        }
    };

    @Override
    protected void onDestroy() {
        super.onDestroy();
        unregisterReceiver(usbReceiver);
        if (pdfSigner != null) {
            pdfSigner.cleanup();
        }
    }
}
