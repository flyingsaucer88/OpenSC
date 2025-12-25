/*
 * USB Device Information class
 *
 * Simple data class for USB device information from libusb
 *
 * Copyright (C) 2024 OpenSC Project
 * Licensed under LGPL 2.1+
 */

package org.opensc.android;

/**
 * USB Device Information
 *
 * Contains basic USB device information from libusb
 */
public class UsbDeviceInfo {
    public final int vendorId;
    public final int productId;
    public final int busNumber;
    public final int deviceAddress;

    /**
     * Constructor
     *
     * @param vendorId USB vendor ID
     * @param productId USB product ID
     * @param busNumber USB bus number
     * @param deviceAddress USB device address
     */
    public UsbDeviceInfo(int vendorId, int productId, int busNumber, int deviceAddress) {
        this.vendorId = vendorId;
        this.productId = productId;
        this.busNumber = busNumber;
        this.deviceAddress = deviceAddress;
    }

    @Override
    public String toString() {
        return String.format("USB Device: VID=0x%04x PID=0x%04x Bus=%d Addr=%d",
                           vendorId, productId, busNumber, deviceAddress);
    }
}
