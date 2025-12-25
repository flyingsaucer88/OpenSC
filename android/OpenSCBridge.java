/*
 * OpenSC Bridge for Android
 *
 * High-level JNI wrapper for OpenSC functionality on Android
 *
 * Copyright (C) 2024 OpenSC Project
 * Licensed under LGPL 2.1+
 */

package org.opensc.android;

import android.content.Context;
import android.hardware.usb.UsbDevice;
import android.util.Log;

import java.util.ArrayList;
import java.util.List;

/**
 * OpenSC Bridge
 *
 * Main interface for using OpenSC functionality on Android.
 * Handles USB device management and provides access to smart card operations.
 */
public class OpenSCBridge {
    private static final String TAG = "OpenSC-Bridge";

    private Context context;
    private UsbManager usbManager;
    private boolean initialized = false;

    /* Native library loading */
    static {
        // Load libraries in correct order
        System.loadLibrary("crypto");      // OpenSSL crypto
        System.loadLibrary("ssl");         // OpenSSL SSL
        System.loadLibrary("usb-1.0");     // libusb
        System.loadLibrary("opensc");      // OpenSC core
        System.loadLibrary("usb-android"); // Our USB bridge
    }

    /* Native methods for OpenSC */
    private native int initializeOpenSC();
    private native void cleanupOpenSC();
    private native String[] listReaders();
    private native boolean isCardPresent(int readerIndex);
    private native String getCardATR(int readerIndex);
    private native String getCardInfo(int readerIndex);

    /**
     * Constructor
     *
     * @param context Android application context
     */
    public OpenSCBridge(Context context) {
        this.context = context;
        Log.i(TAG, "Creating OpenSC Bridge");
    }

    /**
     * Initialize OpenSC and USB subsystem
     *
     * @return true if successful
     */
    public boolean initialize() {
        if (initialized) {
            Log.w(TAG, "Already initialized");
            return true;
        }

        Log.i(TAG, "Initializing OpenSC Bridge");

        try {
            // Initialize USB manager
            usbManager = new UsbManager(context);

            // Initialize OpenSC native library
            int result = initializeOpenSC();
            if (result != 0) {
                Log.e(TAG, "Failed to initialize OpenSC: " + result);
                return false;
            }

            initialized = true;
            Log.i(TAG, "OpenSC Bridge initialized successfully");
            return true;

        } catch (Exception e) {
            Log.e(TAG, "Exception during initialization", e);
            return false;
        }
    }

    /**
     * Cleanup resources
     */
    public void cleanup() {
        if (!initialized) {
            return;
        }

        Log.i(TAG, "Cleaning up OpenSC Bridge");

        cleanupOpenSC();

        if (usbManager != null) {
            usbManager.cleanup();
            usbManager = null;
        }

        initialized = false;
        Log.i(TAG, "OpenSC Bridge cleaned up");
    }

    /**
     * Get list of CCID smart card readers
     *
     * @return List of CCID reader devices
     */
    public List<UsbDevice> getCCIDReaders() {
        if (!initialized || usbManager == null) {
            Log.e(TAG, "Not initialized");
            return new ArrayList<>();
        }

        return usbManager.getCCIDDevices();
    }

    /**
     * Open CCID reader device
     *
     * @param device USB device to open
     * @return true if successful
     */
    public boolean openReader(UsbDevice device) {
        if (!initialized || usbManager == null) {
            Log.e(TAG, "Not initialized");
            return false;
        }

        if (!usbManager.isCCIDDevice(device)) {
            Log.e(TAG, "Device is not a CCID reader: " + device.getDeviceName());
            return false;
        }

        long handle = usbManager.openDevice(device);
        return handle != 0;
    }

    /**
     * Close CCID reader device
     *
     * @param device USB device to close
     */
    public void closeReader(UsbDevice device) {
        if (usbManager != null) {
            usbManager.closeDevice(device);
        }
    }

    /**
     * List smart card readers
     *
     * @return Array of reader names
     */
    public String[] listReaders() {
        if (!initialized) {
            Log.e(TAG, "Not initialized");
            return new String[0];
        }

        return listReaders();
    }

    /**
     * Check if card is present in reader
     *
     * @param readerIndex Reader index (0-based)
     * @return true if card present
     */
    public boolean isCardPresent(int readerIndex) {
        if (!initialized) {
            Log.e(TAG, "Not initialized");
            return false;
        }

        return isCardPresent(readerIndex);
    }

    /**
     * Get card ATR (Answer To Reset)
     *
     * @param readerIndex Reader index (0-based)
     * @return ATR as hex string, or null if error
     */
    public String getCardATR(int readerIndex) {
        if (!initialized) {
            Log.e(TAG, "Not initialized");
            return null;
        }

        return getCardATR(readerIndex);
    }

    /**
     * Get card information
     *
     * @param readerIndex Reader index (0-based)
     * @return Card information string, or null if error
     */
    public String getCardInfo(int readerIndex) {
        if (!initialized) {
            Log.e(TAG, "Not initialized");
            return null;
        }

        return getCardInfo(readerIndex);
    }

    /**
     * Get USB manager
     *
     * @return USB manager instance
     */
    public UsbManager getUsbManager() {
        return usbManager;
    }

    /**
     * Check if initialized
     *
     * @return true if initialized
     */
    public boolean isInitialized() {
        return initialized;
    }
}
