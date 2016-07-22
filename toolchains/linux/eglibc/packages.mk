###############################################################################
## @file toolchains/linux/eglibc/packages.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Additional packages for linux/eglibc toolchain.
###############################################################################

LOCAL_PATH := $(call my-dir)

# Version specific fixes.
ifneq ("$(call str-starts-with,$(TARGET_CC_PATH),/opt/arm-2012.03)","")
  include $(LOCAL_PATH)/arm-2012.03/atom.mk
endif
