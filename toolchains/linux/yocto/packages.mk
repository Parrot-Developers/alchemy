###############################################################################
## @file linux/yocto/packages.mk
## @author A. Bouaziz
## @date 2015/10/29
##
## This file contains package definition specific to yocto
###############################################################################

LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := libc
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := libcrypto
LOCAL_EXPORT_LDLIBS := -lcrypto
include $(BUILD_PREBUILT)

include $(CLEAR_VARS)
LOCAL_MODULE := libssl
LOCAL_EXPORT_LDLIBS := -lssl
include $(BUILD_PREBUILT)
