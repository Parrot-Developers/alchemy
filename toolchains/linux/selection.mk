###############################################################################
## @file toolchains/linux/selection.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Setup toolchain variables.
###############################################################################

ifneq ("$(TARGET_LIBC)","")
  -include $(BUILD_SYSTEM)/toolchains/$(TARGET_OS)/$(TARGET_LIBC)/selection.mk
endif
