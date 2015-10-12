###############################################################################
## @file toolchains-packages.mk
## @author Y.M. Morgan
## @date 2012/11/08
##
## This file contains additional packages for toolchains.
###############################################################################

# Only include libc if not already present in a used sdk
is-full-system := 0
ifneq ("$(TOOLCHAIN_LIBC)","")
  ifeq ("$(call is-module-registered,libc)","")
    include $(BUILD_SYSTEM)/toolchains/libc.mk
    is-full-system := 1
  endif
endif

# Include os specific packages
include $(BUILD_SYSTEM)/toolchains/$(TARGET_OS)/packages.mk
