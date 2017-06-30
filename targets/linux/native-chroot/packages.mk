###############################################################################
## @file targets/linux/native-chroot/packages.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Additional packages for linux/native-chroot target.
###############################################################################

LOCAL_PATH := $(call my-dir)

# Declare linux module if we have headers
ifneq ("$(wildcard /lib/modules/$(TARGET_LINUX_RELEASE)/build)","")
  include $(CLEAR_VARS)
  LOCAL_MODULE := linux
  $(call local-register-prebuilt-overridable)
endif
