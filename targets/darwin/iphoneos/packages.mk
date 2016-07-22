###############################################################################
## @file targets/darwin/iphoneos/packages.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Additional packages for darwin/iphoneos target.
###############################################################################

LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := zlib
LOCAL_EXPORT_LDLIBS := -lz
include $(BUILD_PREBUILT)
