###############################################################################
## @file targets/linux/android/packages.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Additional packages for linux/android target.
###############################################################################

LOCAL_PATH := $(call my-dir)

ifdef USE_ALCHEMY_ANDROID_SDK
  USE_ALCHEMY_ANDROID_BUSYDROID ?= 1
  ifeq ("$(USE_ALCHEMY_ANDROID_BUSYDROID)","1")
    include $(CLEAR_VARS)
    LOCAL_MODULE := busybox
    include $(BUILD_PREBUILT)
  endif
else
  include $(CLEAR_VARS)
    LOCAL_MODULE := zlib
    LOCAL_EXPORT_LDLIBS := -lz
    include $(BUILD_PREBUILT)
endif
