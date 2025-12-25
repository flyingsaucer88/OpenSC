/*
 * Android USB Manager for OpenSC
 *
 * Java wrapper for USB host API integration with libusb/OpenSC
 *
 * Copyright (C) 2024 OpenSC Project
 * Licensed under LGPL 2.1+
 */

package org.opensc.android;

import android.content.Context;
import android.hardware.usb.UsbDevice;
import android.hardware.usb.UsbDeviceConnection;
import android.hardware.usb.UsbManager;
import android.util.Log;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

/**
 * USB Manager for OpenSC on Android
 *
 * This class bridges Android's USB host API with libusb, allowing OpenSC
 * to access USB CCID smart card readers on Android devices.
 */
public class UsbManager {
    private static final String TAG = "OpenSC-UsbManager";

    private Context context;
    private android.hardware.usb.UsbManager usbManager;
    private HashMap<String, Long> openDevices = new HashMap<>();

    /* Native methods */
    static {
        System.loadLibrary("usb-android");
    }

    private native int initializeLibusb();
    private native void cleanupLibusb();
    private native long openDevice(int fd, int vendorId, int productId, String deviceName);
    private native void closeDevice(long deviceHandle);
    private native UsbDeviceInfo[] getDeviceList();
    private native boolean isCCIDDevice(int vendorId, int productId);
    private native String getDeviceDescriptor(int vendorId, int productId);

    /**
     * Constructor
     *
     * @param context Android application context
     */
    public UsbManager(Context context) {
        this.context = context;
        this.usbManager = (android.hardware.usb.UsbManager)
            context.getSystemService(Context.USB_SERVICE);

        int result = initializeLibusb();
        if (result != 0) {
            Log.e(TAG, "Failed to initialize libusb: " + result);
            throw new RuntimeException("Failed to initialize libusb");
        }

        Log.i(TAG, "UsbManager initialized successfully");
    }

    /**
     * Cleanup resources
     */
    public void cleanup() {
        Log.i(TAG, "Cleaning up UsbManager");

        // Close all open devices
        for (Long handle : openDevices.values()) {
            closeDevice(handle);
        }
        openDevices.clear();

        cleanupLibusb();
    }

    /**
     * Get list of all USB devices
     *
     * @return List of USB devices
     */
    public List<UsbDevice> getDevices() {
        HashMap<String, UsbDevice> deviceList = usbManager.getDeviceList();
        return new ArrayList<>(deviceList.values());
    }

    /**
     * Get list of CCID smart card readers
     *
     * @return List of CCID devices
     */
    public List<UsbDevice> getCCIDDevices() {
        List<UsbDevice> ccidDevices = new ArrayList<>();

        for (UsbDevice device : getDevices()) {
            if (isCCIDDevice(device.getVendorId(), device.getProductId())) {
                ccidDevices.add(device);
                Log.i(TAG, "Found CCID device: " + device.getDeviceName());
            }
        }

        return ccidDevices;
    }

    /**
     * Check if device is a CCID smart card reader
     *
     * @param device USB device to check
     * @return true if device is CCID
     */
    public boolean isCCIDDevice(UsbDevice device) {
        return isCCIDDevice(device.getVendorId(), device.getProductId());
    }

    /**
     * Open USB device for libusb
     *
     * @param device USB device to open
     * @return Device handle, or 0 on failure
     */
    public long openDevice(UsbDevice device) {
        String deviceName = device.getDeviceName();

        // Check if already open
        if (openDevices.containsKey(deviceName)) {
            Log.w(TAG, "Device already open: " + deviceName);
            return openDevices.get(deviceName);
        }

        // Check permission
        if (!usbManager.hasPermission(device)) {
            Log.e(TAG, "No permission for device: " + deviceName);
            return 0;
        }

        // Open device connection
        UsbDeviceConnection connection = usbManager.openDevice(device);
        if (connection == null) {
            Log.e(TAG, "Failed to open device connection: " + deviceName);
            return 0;
        }

        // Get file descriptor
        int fd = connection.getFileDescriptor();

        Log.i(TAG, "Opening device: " + deviceName + " (fd=" + fd + ")");

        // Open device in native code
        long handle = openDevice(fd, device.getVendorId(), device.getProductId(), deviceName);

        if (handle != 0) {
            openDevices.put(deviceName, handle);
            Log.i(TAG, "Device opened successfully: " + deviceName);
        } else {
            connection.close();
            Log.e(TAG, "Failed to open device in native code: " + deviceName);
        }

        return handle;
    }

    /**
     * Close USB device
     *
     * @param deviceName Device name to close
     */
    public void closeDevice(String deviceName) {
        Long handle = openDevices.get(deviceName);
        if (handle != null) {
            Log.i(TAG, "Closing device: " + deviceName);
            closeDevice(handle);
            openDevices.remove(deviceName);
        } else {
            Log.w(TAG, "Device not open: " + deviceName);
        }
    }

    /**
     * Close USB device
     *
     * @param device USB device to close
     */
    public void closeDevice(UsbDevice device) {
        closeDevice(device.getDeviceName());
    }

    /**
     * Get device descriptor string
     *
     * @param device USB device
     * @return Device descriptor string
     */
    public String getDeviceDescriptor(UsbDevice device) {
        return getDeviceDescriptor(device.getVendorId(), device.getProductId());
    }

    /**
     * Get device info string for display
     *
     * @param device USB device
     * @return Human-readable device info
     */
    public String getDeviceInfo(UsbDevice device) {
        StringBuilder sb = new StringBuilder();

        sb.append("Device: ").append(device.getDeviceName()).append("\n");
        sb.append("VID: 0x").append(Integer.toHexString(device.getVendorId())).append("\n");
        sb.append("PID: 0x").append(Integer.toHexString(device.getProductId())).append("\n");
        sb.append("Class: ").append(device.getDeviceClass()).append("\n");
        sb.append("Subclass: ").append(device.getDeviceSubclass()).append("\n");
        sb.append("Protocol: ").append(device.getDeviceProtocol()).append("\n");
        sb.append("Interface Count: ").append(device.getInterfaceCount()).append("\n");

        if (device.getManufacturerName() != null) {
            sb.append("Manufacturer: ").append(device.getManufacturerName()).append("\n");
        }
        if (device.getProductName() != null) {
            sb.append("Product: ").append(device.getProductName()).append("\n");
        }
        if (device.getSerialNumber() != null) {
            sb.append("Serial: ").append(device.getSerialNumber()).append("\n");
        }

        sb.append("CCID: ").append(isCCIDDevice(device) ? "Yes" : "No");

        return sb.toString();
    }

    /**
     * Check if we have permission for device
     *
     * @param device USB device
     * @return true if permission granted
     */
    public boolean hasPermission(UsbDevice device) {
        return usbManager.hasPermission(device);
    }

    /**
     * Get number of open devices
     *
     * @return Number of open devices
     */
    public int getOpenDeviceCount() {
        return openDevices.size();
    }
}
