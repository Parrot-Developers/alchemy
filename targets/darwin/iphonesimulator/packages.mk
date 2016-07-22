###############################################################################
## @file targets/darwin/iphonesimulator/packages.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Additional packages for darwin/iphonesimulator target.
###############################################################################

LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := zlib
LOCAL_EXPORT_LDLIBS := -lz
include $(BUILD_PREBUILT)
