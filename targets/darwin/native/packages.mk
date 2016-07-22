###############################################################################
## @file targets/darwin/native/packages.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Additional packages for darwin/native target.
###############################################################################

LOCAL_PATH := $(call my-dir)

$(call register-prebuilt-pkg-config-module,libusb,libusb)
$(call register-prebuilt-pkg-config-module,libusb_1_0,libusb-1.0)
$(call register-prebuilt-pkg-config-module,json,json-c)
