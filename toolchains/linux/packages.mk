###############################################################################
## @file toolchains/linux/packages.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Additional packages for linux toolchain.
###############################################################################

ifneq ("$(TARGET_LIBC)","")
  -include $(BUILD_SYSTEM)/toolchains/$(TARGET_OS)/$(TARGET_LIBC)/packages.mk
endif
