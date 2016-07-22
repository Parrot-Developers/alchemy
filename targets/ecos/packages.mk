###############################################################################
## @file targets/ecos/packages.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Additional packages for ecos target.
###############################################################################

LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := alsa-lib
include $(BUILD_PREBUILT)
