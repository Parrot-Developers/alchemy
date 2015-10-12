###############################################################################
## @file linux/bionic/packages.mk
## @author Y.M. Morgan
## @date 2012/10/18
##
## This file contains package definition specific to bionic (android).
###############################################################################

LOCAL_PATH := $(call my-dir)

# Skip most of this if a sdk is used for the android part
ifdef USE_ALCHEMY_ANDROID_SDK

USE_ALCHEMY_ANDROID_BUSYDROID ?= 1
ifeq ("$(USE_ALCHEMY_ANDROID_BUSYDROID)","1")
include $(CLEAR_VARS)
LOCAL_MODULE := busybox
include $(BUILD_PREBUILT)
endif

endif # ifdef USE_ALCHEMY_ANDROID_SDK
