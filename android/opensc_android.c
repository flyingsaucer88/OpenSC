/*
 * OpenSC JNI wrapper for Android
 *
 * Provides JNI interface to OpenSC functionality for Android apps
 *
 * Copyright (C) 2024 OpenSC Project
 * Licensed under LGPL 2.1+
 */

#include <jni.h>
#include <android/log.h>
#include <libopensc/opensc.h>
#include <libopensc/cardctl.h>
#include <libopensc/pkcs15.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define LOG_TAG "OpenSC-JNI"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, LOG_TAG, __VA_ARGS__)
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGW(...) __android_log_print(ANDROID_LOG_WARN, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

/* Global OpenSC context */
static sc_context_t *ctx = NULL;
static sc_reader_t **readers = NULL;
static unsigned int reader_count = 0;

/*
 * Initialize OpenSC library
 */
JNIEXPORT jint JNICALL
Java_org_opensc_android_OpenSCBridge_initializeOpenSC(JNIEnv *env, jobject obj)
{
    int rc;

    LOGI("Initializing OpenSC");

    if (ctx != NULL) {
        LOGW("OpenSC already initialized");
        return 0;
    }

    /* Establish OpenSC context */
    rc = sc_establish_context(&ctx, "OpenSC-Android");
    if (rc != SC_SUCCESS) {
        LOGE("Failed to establish context: %s", sc_strerror(rc));
        return rc;
    }

    /* Set up debug level */
    ctx->debug = 2; /* INFO level */

    /* Detect readers */
    reader_count = sc_ctx_get_reader_count(ctx);
    LOGI("Found %u readers", reader_count);

    if (reader_count > 0) {
        readers = (sc_reader_t **)calloc(reader_count, sizeof(sc_reader_t *));
        if (!readers) {
            LOGE("Failed to allocate reader array");
            sc_release_context(ctx);
            ctx = NULL;
            return SC_ERROR_OUT_OF_MEMORY;
        }

        for (unsigned int i = 0; i < reader_count; i++) {
            readers[i] = sc_ctx_get_reader(ctx, i);
            if (readers[i]) {
                LOGI("Reader %u: %s", i, readers[i]->name);
            }
        }
    }

    LOGI("OpenSC initialized successfully");
    return 0;
}

/*
 * Cleanup OpenSC library
 */
JNIEXPORT void JNICALL
Java_org_opensc_android_OpenSCBridge_cleanupOpenSC(JNIEnv *env, jobject obj)
{
    LOGI("Cleaning up OpenSC");

    if (readers) {
        free(readers);
        readers = NULL;
    }
    reader_count = 0;

    if (ctx) {
        sc_release_context(ctx);
        ctx = NULL;
    }

    LOGI("OpenSC cleaned up");
}

/*
 * List smart card readers
 */
JNIEXPORT jobjectArray JNICALL
Java_org_opensc_android_OpenSCBridge_listReaders(JNIEnv *env, jobject obj)
{
    jobjectArray result = NULL;
    jclass stringClass;
    unsigned int i;

    LOGD("Listing readers");

    if (!ctx) {
        LOGE("OpenSC not initialized");
        return NULL;
    }

    /* Refresh reader list */
    reader_count = sc_ctx_get_reader_count(ctx);
    LOGD("Found %u readers", reader_count);

    if (reader_count == 0) {
        /* Return empty array */
        stringClass = (*env)->FindClass(env, "java/lang/String");
        return (*env)->NewObjectArray(env, 0, stringClass, NULL);
    }

    /* Create string array */
    stringClass = (*env)->FindClass(env, "java/lang/String");
    if (!stringClass) {
        LOGE("Failed to find String class");
        return NULL;
    }

    result = (*env)->NewObjectArray(env, reader_count, stringClass, NULL);
    if (!result) {
        LOGE("Failed to create result array");
        return NULL;
    }

    /* Fill array with reader names */
    for (i = 0; i < reader_count; i++) {
        sc_reader_t *reader = sc_ctx_get_reader(ctx, i);
        if (reader && reader->name) {
            jstring readerName = (*env)->NewStringUTF(env, reader->name);
            if (readerName) {
                (*env)->SetObjectArrayElement(env, result, i, readerName);
                (*env)->DeleteLocalRef(env, readerName);
            }
        }
    }

    return result;
}

/*
 * Check if card is present in reader
 */
JNIEXPORT jboolean JNICALL
Java_org_opensc_android_OpenSCBridge_isCardPresent(JNIEnv *env, jobject obj, jint readerIndex)
{
    sc_reader_t *reader;
    unsigned int flags;
    int rc;

    LOGD("Checking card presence in reader %d", readerIndex);

    if (!ctx) {
        LOGE("OpenSC not initialized");
        return JNI_FALSE;
    }

    if (readerIndex < 0 || (unsigned int)readerIndex >= reader_count) {
        LOGE("Invalid reader index: %d", readerIndex);
        return JNI_FALSE;
    }

    reader = sc_ctx_get_reader(ctx, (unsigned int)readerIndex);
    if (!reader) {
        LOGE("Failed to get reader %d", readerIndex);
        return JNI_FALSE;
    }

    /* Detect card */
    rc = sc_detect_card_presence(reader);
    if (rc < 0) {
        LOGE("Failed to detect card: %s", sc_strerror(rc));
        return JNI_FALSE;
    }

    flags = sc_reader_get_state(reader);
    LOGD("Reader flags: 0x%x", flags);

    return (flags & SC_READER_CARD_PRESENT) ? JNI_TRUE : JNI_FALSE;
}

/*
 * Get card ATR (Answer To Reset)
 */
JNIEXPORT jstring JNICALL
Java_org_opensc_android_OpenSCBridge_getCardATR(JNIEnv *env, jobject obj, jint readerIndex)
{
    sc_reader_t *reader;
    sc_card_t *card = NULL;
    char atr_str[SC_MAX_ATR_SIZE * 3];
    jstring result = NULL;
    int rc;
    unsigned int i;

    LOGD("Getting ATR from reader %d", readerIndex);

    if (!ctx) {
        LOGE("OpenSC not initialized");
        return NULL;
    }

    if (readerIndex < 0 || (unsigned int)readerIndex >= reader_count) {
        LOGE("Invalid reader index: %d", readerIndex);
        return NULL;
    }

    reader = sc_ctx_get_reader(ctx, (unsigned int)readerIndex);
    if (!reader) {
        LOGE("Failed to get reader %d", readerIndex);
        return NULL;
    }

    /* Connect to card */
    rc = sc_connect_card(reader, &card);
    if (rc != SC_SUCCESS) {
        LOGE("Failed to connect to card: %s", sc_strerror(rc));
        return NULL;
    }

    /* Format ATR as hex string */
    atr_str[0] = '\0';
    for (i = 0; i < card->atr.len; i++) {
        char hex[4];
        snprintf(hex, sizeof(hex), "%02X ", card->atr.value[i]);
        strcat(atr_str, hex);
    }

    LOGI("ATR: %s", atr_str);

    result = (*env)->NewStringUTF(env, atr_str);

    sc_disconnect_card(card);
    return result;
}

/*
 * Get card information
 */
JNIEXPORT jstring JNICALL
Java_org_opensc_android_OpenSCBridge_getCardInfo(JNIEnv *env, jobject obj, jint readerIndex)
{
    sc_reader_t *reader;
    sc_card_t *card = NULL;
    char info_str[1024];
    jstring result = NULL;
    int rc;

    LOGD("Getting card info from reader %d", readerIndex);

    if (!ctx) {
        LOGE("OpenSC not initialized");
        return NULL;
    }

    if (readerIndex < 0 || (unsigned int)readerIndex >= reader_count) {
        LOGE("Invalid reader index: %d", readerIndex);
        return NULL;
    }

    reader = sc_ctx_get_reader(ctx, (unsigned int)readerIndex);
    if (!reader) {
        LOGE("Failed to get reader %d", readerIndex);
        return NULL;
    }

    /* Connect to card */
    rc = sc_connect_card(reader, &card);
    if (rc != SC_SUCCESS) {
        LOGE("Failed to connect to card: %s", sc_strerror(rc));
        return NULL;
    }

    /* Build info string */
    snprintf(info_str, sizeof(info_str),
            "Card Type: %s\n"
            "Driver: %s\n"
            "ATR Length: %zu bytes\n"
            "Max Send: %zu bytes\n"
            "Max Recv: %zu bytes",
            card->name ? card->name : "Unknown",
            card->driver ? card->driver->name : "Unknown",
            card->atr.len,
            card->max_send_size,
            card->max_recv_size);

    LOGI("Card info: %s", info_str);

    result = (*env)->NewStringUTF(env, info_str);

    sc_disconnect_card(card);
    return result;
}

/*
 * PKCS#15 PIN verification
 */
JNIEXPORT jboolean JNICALL
Java_org_opensc_android_OpenSCBridge_verifyPIN(JNIEnv *env, jobject obj,
                                                jint readerIndex, jstring pin)
{
    sc_reader_t *reader;
    sc_card_t *card = NULL;
    sc_pkcs15_card_t *p15card = NULL;
    sc_pkcs15_object_t *pin_obj = NULL;
    sc_pkcs15_auth_info_t *pin_info;
    const char *pin_str;
    int rc;
    jboolean result = JNI_FALSE;

    if (!ctx || !pin) {
        return JNI_FALSE;
    }

    if (readerIndex < 0 || (unsigned int)readerIndex >= reader_count) {
        LOGE("Invalid reader index: %d", readerIndex);
        return JNI_FALSE;
    }

    reader = sc_ctx_get_reader(ctx, (unsigned int)readerIndex);
    if (!reader) {
        return JNI_FALSE;
    }

    /* Connect to card */
    rc = sc_connect_card(reader, &card);
    if (rc != SC_SUCCESS) {
        LOGE("Failed to connect to card: %s", sc_strerror(rc));
        return JNI_FALSE;
    }

    /* Bind PKCS#15 */
    rc = sc_pkcs15_bind(card, NULL, &p15card);
    if (rc != SC_SUCCESS) {
        LOGE("Failed to bind PKCS#15: %s", sc_strerror(rc));
        sc_disconnect_card(card);
        return JNI_FALSE;
    }

    /* Find first PIN */
    rc = sc_pkcs15_find_pin_by_auth_id(p15card, NULL, &pin_obj);
    if (rc != SC_SUCCESS) {
        LOGE("Failed to find PIN: %s", sc_strerror(rc));
        goto cleanup;
    }

    pin_info = (sc_pkcs15_auth_info_t *)pin_obj->data;
    pin_str = (*env)->GetStringUTFChars(env, pin, NULL);

    /* Verify PIN */
    rc = sc_pkcs15_verify_pin(p15card, pin_obj, (const u8 *)pin_str, strlen(pin_str));

    (*env)->ReleaseStringUTFChars(env, pin, pin_str);

    if (rc == SC_SUCCESS) {
        LOGI("PIN verified successfully");
        result = JNI_TRUE;
    } else {
        LOGE("PIN verification failed: %s", sc_strerror(rc));
    }

cleanup:
    if (p15card) {
        sc_pkcs15_unbind(p15card);
    }
    sc_disconnect_card(card);

    return result;
}
