# CMakeLists.txt for OpenSC Android USB integration layer
#
# This builds the JNI bridge libraries for OpenSC on Android using CMake

cmake_minimum_required(VERSION 3.10)
project(opensc-android)

# Android API level
set(ANDROID_API_LEVEL 21)

# Build directories - adjust based on ABI
if(NOT DEFINED ANDROID_ABI)
    set(ANDROID_ABI "arm64-v8a")
endif()

set(BUILD_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../build-android")
set(OPENSC_DIR "${BUILD_ROOT}/opensc-install/${ANDROID_ABI}")
set(LIBUSB_DIR "${BUILD_ROOT}/install/${ANDROID_ABI}")
set(OPENSSL_DIR "${BUILD_ROOT}/openssl-install/${ANDROID_ABI}")

# Find Android log library
find_library(log-lib log)
find_library(android-lib android)

#================================================================
# USB Android Bridge Library
#================================================================
add_library(usb-android SHARED
    usb_android.c
)

target_include_directories(usb-android PRIVATE
    ${LIBUSB_DIR}/include/libusb-1.0
)

target_link_libraries(usb-android
    ${LIBUSB_DIR}/lib/libusb-1.0.so
    ${log-lib}
    ${android-lib}
)

#================================================================
# OpenSC Android Bridge Library
#================================================================
add_library(opensc-android SHARED
    opensc_android.c
)

target_include_directories(opensc-android PRIVATE
    ${OPENSC_DIR}/include
    ${OPENSSL_DIR}/include
    ${LIBUSB_DIR}/include/libusb-1.0
)

target_link_libraries(opensc-android
    ${OPENSC_DIR}/lib/libopensc.so
    ${OPENSSL_DIR}/lib/libcrypto.so
    ${OPENSSL_DIR}/lib/libssl.so
    ${LIBUSB_DIR}/lib/libusb-1.0.so
    ${log-lib}
)

#================================================================
# Installation
#================================================================
install(TARGETS usb-android opensc-android
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
)

# Install additional required libraries
install(FILES
    ${LIBUSB_DIR}/lib/libusb-1.0.so
    ${OPENSSL_DIR}/lib/libcrypto.so
    ${OPENSSL_DIR}/lib/libssl.so
    ${OPENSC_DIR}/lib/libopensc.so
    ${OPENSC_DIR}/lib/opensc-pkcs11.so
    DESTINATION ${CMAKE_INSTALL_LIBDIR}
    OPTIONAL
)
