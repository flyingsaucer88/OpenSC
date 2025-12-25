# Android.mk for OpenSC Android USB integration layer
#
# This builds the JNI bridge libraries for OpenSC on Android

LOCAL_PATH := $(call my-dir)

# Build directory (adjust if needed)
OPENSC_BUILD_DIR := ../build-android/opensc-install/$(TARGET_ARCH_ABI)
LIBUSB_BUILD_DIR := ../build-android/install/$(TARGET_ARCH_ABI)
OPENSSL_BUILD_DIR := ../build-android/openssl-install/$(TARGET_ARCH_ABI)

#================================================================
# USB Android Bridge Library
#================================================================
include $(CLEAR_VARS)

LOCAL_MODULE := usb-android
LOCAL_SRC_FILES := usb_android.c
LOCAL_C_INCLUDES := \
    $(LIBUSB_BUILD_DIR)/include/libusb-1.0

LOCAL_SHARED_LIBRARIES := libusb-1.0
LOCAL_LDLIBS := -llog -landroid

include $(BUILD_SHARED_LIBRARY)

#================================================================
# OpenSC Android Bridge Library
#================================================================
include $(CLEAR_VARS)

LOCAL_MODULE := opensc-android
LOCAL_SRC_FILES := opensc_android.c
LOCAL_C_INCLUDES := \
    $(OPENSC_BUILD_DIR)/include \
    $(OPENSSL_BUILD_DIR)/include \
    $(LIBUSB_BUILD_DIR)/include/libusb-1.0

LOCAL_SHARED_LIBRARIES := libopensc libusb-1.0 libcrypto libssl
LOCAL_LDLIBS := -llog

include $(BUILD_SHARED_LIBRARY)

#================================================================
# Prebuilt Libraries
#================================================================

# libusb-1.0
include $(CLEAR_VARS)
LOCAL_MODULE := libusb-1.0
LOCAL_SRC_FILES := $(LIBUSB_BUILD_DIR)/lib/libusb-1.0.so
LOCAL_EXPORT_C_INCLUDES := $(LIBUSB_BUILD_DIR)/include/libusb-1.0
include $(PREBUILT_SHARED_LIBRARY)

# OpenSSL crypto
include $(CLEAR_VARS)
LOCAL_MODULE := libcrypto
LOCAL_SRC_FILES := $(OPENSSL_BUILD_DIR)/lib/libcrypto.so
LOCAL_EXPORT_C_INCLUDES := $(OPENSSL_BUILD_DIR)/include
include $(PREBUILT_SHARED_LIBRARY)

# OpenSSL ssl
include $(CLEAR_VARS)
LOCAL_MODULE := libssl
LOCAL_SRC_FILES := $(OPENSSL_BUILD_DIR)/lib/libssl.so
LOCAL_EXPORT_C_INCLUDES := $(OPENSSL_BUILD_DIR)/include
include $(PREBUILT_SHARED_LIBRARY)

# OpenSC
include $(CLEAR_VARS)
LOCAL_MODULE := libopensc
LOCAL_SRC_FILES := $(OPENSC_BUILD_DIR)/lib/libopensc.so
LOCAL_EXPORT_C_INCLUDES := $(OPENSC_BUILD_DIR)/include
include $(PREBUILT_SHARED_LIBRARY)
