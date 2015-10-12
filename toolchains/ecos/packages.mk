###############################################################################
## @file ecos/packages.mk
## @author Y.M. Morgan
## @date 2012/10/18
##
## This file contains package definition specific to ecos.
###############################################################################

LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := alsa-lib
LOCAL_MODULE_CLASS := PREBUILT
include $(BUILD_PREBUILT)
