###############################################################################
## @file targets/linux/yocto/packages.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Additional packages for linux/yocto target.
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
