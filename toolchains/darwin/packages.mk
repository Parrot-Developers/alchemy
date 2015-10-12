###############################################################################
## @file darwin/packages.mk
## @author F.Ferrand
## @date 2015/04/10
##
## This file contains additional setup for apple toolchains (ios, macos).
###############################################################################

LOCAL_PATH := $(call my-dir)

ifeq ("$(TARGET_OS_FLAVOUR)","native")

ifeq ("$(shell pkg-config --exists libusb; echo $$?)","0")
include $(CLEAR_VARS)
# can be installed with: brew install libusb-compat
LOCAL_MODULE := libusb
LOCAL_EXPORT_CFLAGS := $(shell pkg-config --cflags libusb)
LOCAL_EXPORT_LDLIBS := $(shell pkg-config --libs libusb)
include $(BUILD_PREBUILT)
endif

ifeq ("$(shell pkg-config --exists libusb-1.0; echo $$?)","0")
include $(CLEAR_VARS)
# can be installed with: brew install libusb
LOCAL_MODULE := libusb_1_0
LOCAL_EXPORT_CFLAGS := $(shell pkg-config --cflags libusb-1.0)
LOCAL_EXPORT_LDLIBS := $(shell pkg-config --libs libusb-1.0)
include $(BUILD_PREBUILT)
endif

ifeq ("$(shell pkg-config --exists zlib; echo $$?)","0")
include $(CLEAR_VARS)
# installed by default
LOCAL_MODULE := zlib
LOCAL_EXPORT_CFLAGS := $(shell pkg-config --cflags zlib)
LOCAL_EXPORT_LDLIBS := $(shell pkg-config --libs zlib)
include $(BUILD_PREBUILT)
endif

ifeq ("$(shell pkg-config --exists json-c; echo $$?)","0")
include $(CLEAR_VARS)
# can be installed with: brew install json-c
LOCAL_MODULE := json
LOCAL_EXPORT_CFLAGS := $(shell pkg-config --cflags json-c)
LOCAL_EXPORT_LDLIBS := $(shell pkg-config --libs json-c)
include $(BUILD_PREBUILT)
endif

endif

