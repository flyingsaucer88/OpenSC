/*
 * Android USB Host API integration layer for libusb/OpenSC
 *
 * This file provides a bridge between Android's USB host API and libusb,
 * allowing OpenSC to access USB CCID smart card readers on Android.
 *
 * Copyright (C) 2024 OpenSC Project
 * Licensed under LGPL 2.1+
 */

#include <jni.h>
#include <android/log.h>
#include <libusb-1.0/libusb.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>

#define LOG_TAG "OpenSC-USB"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

/* Global USB context */
static libusb_context *usb_context = NULL;
static JavaVM *cached_jvm = NULL;

/* USB device info structure */
typedef struct {
    int fd;
    char device_name[256];
    uint16_t vendor_id;
    uint16_t product_id;
    uint8_t bus_number;
    uint8_t device_address;
} android_usb_device_t;

/*
 * Initialize libusb with Android-specific settings
 */
JNIEXPORT jint JNICALL
Java_org_opensc_android_UsbManager_initializeLibusb(JNIEnv *env, jobject obj)
{
    int rc;

    LOGI("Initializing libusb for Android");

    if (usb_context != NULL) {
        LOGW("libusb already initialized");
        return 0;
    }

    rc = libusb_init(&usb_context);
    if (rc < 0) {
        LOGE("Failed to initialize libusb: %s", libusb_error_name(rc));
        return rc;
    }

    /* Set debug level for development */
    libusb_set_option(usb_context, LIBUSB_OPTION_LOG_LEVEL, LIBUSB_LOG_LEVEL_INFO);

    /* Cache JVM for callbacks */
    (*env)->GetJavaVM(env, &cached_jvm);

    LOGI("libusb initialized successfully");
    return 0;
}

/*
 * Cleanup libusb
 */
JNIEXPORT void JNICALL
Java_org_opensc_android_UsbManager_cleanupLibusb(JNIEnv *env, jobject obj)
{
    LOGI("Cleaning up libusb");

    if (usb_context != NULL) {
        libusb_exit(usb_context);
        usb_context = NULL;
    }

    cached_jvm = NULL;
    LOGI("libusb cleaned up");
}

/*
 * Open Android USB device and wrap it for libusb
 *
 * This function takes a file descriptor obtained from Android's UsbManager
 * and wraps it for use with libusb.
 */
JNIEXPORT jlong JNICALL
Java_org_opensc_android_UsbManager_openDevice(JNIEnv *env, jobject obj,
                                               jint fd, jint vendorId,
                                               jint productId, jstring deviceName)
{
    android_usb_device_t *device;
    const char *name_str;
    int rc;

    LOGI("Opening USB device: fd=%d, vid=0x%04x, pid=0x%04x", fd, vendorId, productId);

    if (usb_context == NULL) {
        LOGE("libusb not initialized");
        return 0;
    }

    /* Allocate device structure */
    device = (android_usb_device_t *)calloc(1, sizeof(android_usb_device_t));
    if (!device) {
        LOGE("Failed to allocate device structure");
        return 0;
    }

    /* Store device information */
    device->fd = fd;
    device->vendor_id = (uint16_t)vendorId;
    device->product_id = (uint16_t)productId;

    /* Copy device name */
    name_str = (*env)->GetStringUTFChars(env, deviceName, NULL);
    if (name_str) {
        strncpy(device->device_name, name_str, sizeof(device->device_name) - 1);
        (*env)->ReleaseStringUTFChars(env, deviceName, name_str);
    }

    LOGI("Device opened successfully: %s", device->device_name);
    return (jlong)(uintptr_t)device;
}

/*
 * Close Android USB device
 */
JNIEXPORT void JNICALL
Java_org_opensc_android_UsbManager_closeDevice(JNIEnv *env, jobject obj, jlong deviceHandle)
{
    android_usb_device_t *device = (android_usb_device_t *)(uintptr_t)deviceHandle;

    if (!device) {
        LOGW("Attempted to close NULL device");
        return;
    }

    LOGI("Closing USB device: %s", device->device_name);

    /* Close file descriptor if still open */
    if (device->fd >= 0) {
        close(device->fd);
        device->fd = -1;
    }

    free(device);
    LOGI("Device closed");
}

/*
 * Get list of USB devices
 *
 * Returns array of device information as a Java object array
 */
JNIEXPORT jobjectArray JNICALL
Java_org_opensc_android_UsbManager_getDeviceList(JNIEnv *env, jobject obj)
{
    libusb_device **devs;
    ssize_t cnt;
    int i;
    jobjectArray result = NULL;
    jclass deviceInfoClass;
    jmethodID constructor;

    LOGI("Getting USB device list");

    if (usb_context == NULL) {
        LOGE("libusb not initialized");
        return NULL;
    }

    cnt = libusb_get_device_list(usb_context, &devs);
    if (cnt < 0) {
        LOGE("Failed to get device list: %s", libusb_error_name(cnt));
        return NULL;
    }

    LOGI("Found %zd USB devices", cnt);

    /* Find DeviceInfo class and constructor */
    deviceInfoClass = (*env)->FindClass(env, "org/opensc/android/UsbDeviceInfo");
    if (!deviceInfoClass) {
        LOGE("Failed to find UsbDeviceInfo class");
        libusb_free_device_list(devs, 1);
        return NULL;
    }

    constructor = (*env)->GetMethodID(env, deviceInfoClass, "<init>", "(IIII)V");
    if (!constructor) {
        LOGE("Failed to find UsbDeviceInfo constructor");
        libusb_free_device_list(devs, 1);
        return NULL;
    }

    /* Create result array */
    result = (*env)->NewObjectArray(env, cnt, deviceInfoClass, NULL);
    if (!result) {
        LOGE("Failed to create result array");
        libusb_free_device_list(devs, 1);
        return NULL;
    }

    /* Populate array with device info */
    for (i = 0; i < cnt; i++) {
        struct libusb_device_descriptor desc;
        int rc;
        jobject deviceInfo;

        rc = libusb_get_device_descriptor(devs[i], &desc);
        if (rc < 0) {
            LOGW("Failed to get device descriptor for device %d: %s",
                 i, libusb_error_name(rc));
            continue;
        }

        /* Create DeviceInfo object */
        deviceInfo = (*env)->NewObject(env, deviceInfoClass, constructor,
                                       desc.idVendor,
                                       desc.idProduct,
                                       libusb_get_bus_number(devs[i]),
                                       libusb_get_device_address(devs[i]));

        if (deviceInfo) {
            (*env)->SetObjectArrayElement(env, result, i, deviceInfo);
            (*env)->DeleteLocalRef(env, deviceInfo);
        }
    }

    libusb_free_device_list(devs, 1);
    LOGI("Device list retrieved successfully");

    return result;
}

/*
 * Check if device is a CCID smart card reader
 *
 * Returns true if the device has the CCID interface class
 */
JNIEXPORT jboolean JNICALL
Java_org_opensc_android_UsbManager_isCCIDDevice(JNIEnv *env, jobject obj,
                                                 jint vendorId, jint productId)
{
    libusb_device **devs;
    libusb_device *dev = NULL;
    ssize_t cnt;
    int i, j, k;
    jboolean is_ccid = JNI_FALSE;

    LOGD("Checking if device is CCID: vid=0x%04x, pid=0x%04x", vendorId, productId);

    if (usb_context == NULL) {
        LOGE("libusb not initialized");
        return JNI_FALSE;
    }

    cnt = libusb_get_device_list(usb_context, &devs);
    if (cnt < 0) {
        LOGE("Failed to get device list: %s", libusb_error_name(cnt));
        return JNI_FALSE;
    }

    /* Find matching device */
    for (i = 0; i < cnt; i++) {
        struct libusb_device_descriptor desc;

        if (libusb_get_device_descriptor(devs[i], &desc) < 0)
            continue;

        if (desc.idVendor == vendorId && desc.idProduct == productId) {
            dev = devs[i];
            break;
        }
    }

    if (!dev) {
        LOGD("Device not found in USB device list");
        libusb_free_device_list(devs, 1);
        return JNI_FALSE;
    }

    /* Check device configuration for CCID interface */
    for (i = 0; i < desc.bNumConfigurations; i++) {
        struct libusb_config_descriptor *config;

        if (libusb_get_config_descriptor(dev, i, &config) < 0)
            continue;

        for (j = 0; j < config->bNumInterfaces; j++) {
            const struct libusb_interface *iface = &config->interface[j];

            for (k = 0; k < iface->num_altsetting; k++) {
                const struct libusb_interface_descriptor *altsetting = &iface->altsetting[k];

                /* CCID interface class is 0x0B (Chip/Smart Card) */
                if (altsetting->bInterfaceClass == 0x0B) {
                    LOGI("Device is CCID: vid=0x%04x, pid=0x%04x", vendorId, productId);
                    is_ccid = JNI_TRUE;
                    libusb_free_config_descriptor(config);
                    goto cleanup;
                }
            }
        }

        libusb_free_config_descriptor(config);
    }

cleanup:
    libusb_free_device_list(devs, 1);
    return is_ccid;
}

/*
 * Get device descriptor as string for debugging
 */
JNIEXPORT jstring JNICALL
Java_org_opensc_android_UsbManager_getDeviceDescriptor(JNIEnv *env, jobject obj,
                                                        jint vendorId, jint productId)
{
    libusb_device **devs;
    libusb_device *dev = NULL;
    libusb_device_handle *handle = NULL;
    ssize_t cnt;
    int i;
    char desc_str[1024];
    jstring result = NULL;

    if (usb_context == NULL) {
        return (*env)->NewStringUTF(env, "libusb not initialized");
    }

    cnt = libusb_get_device_list(usb_context, &devs);
    if (cnt < 0) {
        return (*env)->NewStringUTF(env, "Failed to get device list");
    }

    /* Find matching device */
    for (i = 0; i < cnt; i++) {
        struct libusb_device_descriptor desc;

        if (libusb_get_device_descriptor(devs[i], &desc) < 0)
            continue;

        if (desc.idVendor == vendorId && desc.idProduct == productId) {
            dev = devs[i];
            break;
        }
    }

    if (!dev) {
        libusb_free_device_list(devs, 1);
        return (*env)->NewStringUTF(env, "Device not found");
    }

    /* Try to open device and get string descriptors */
    if (libusb_open(dev, &handle) == 0) {
        struct libusb_device_descriptor desc;
        unsigned char manufacturer[256] = {0};
        unsigned char product[256] = {0};
        unsigned char serial[256] = {0};

        libusb_get_device_descriptor(dev, &desc);

        if (desc.iManufacturer > 0) {
            libusb_get_string_descriptor_ascii(handle, desc.iManufacturer,
                                               manufacturer, sizeof(manufacturer));
        }
        if (desc.iProduct > 0) {
            libusb_get_string_descriptor_ascii(handle, desc.iProduct,
                                               product, sizeof(product));
        }
        if (desc.iSerialNumber > 0) {
            libusb_get_string_descriptor_ascii(handle, desc.iSerialNumber,
                                               serial, sizeof(serial));
        }

        snprintf(desc_str, sizeof(desc_str),
                "VID: 0x%04x PID: 0x%04x\n"
                "Manufacturer: %s\n"
                "Product: %s\n"
                "Serial: %s\n"
                "Bus: %d Address: %d",
                desc.idVendor, desc.idProduct,
                manufacturer[0] ? (char*)manufacturer : "N/A",
                product[0] ? (char*)product : "N/A",
                serial[0] ? (char*)serial : "N/A",
                libusb_get_bus_number(dev),
                libusb_get_device_address(dev));

        libusb_close(handle);
    } else {
        struct libusb_device_descriptor desc;
        libusb_get_device_descriptor(dev, &desc);

        snprintf(desc_str, sizeof(desc_str),
                "VID: 0x%04x PID: 0x%04x (details unavailable)",
                desc.idVendor, desc.idProduct);
    }

    libusb_free_device_list(devs, 1);
    result = (*env)->NewStringUTF(env, desc_str);

    return result;
}
