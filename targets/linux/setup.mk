###############################################################################
## @file targets/linux/setup.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Setup variables for linux target.
###############################################################################

TARGET_STATIC_LIB_SUFFIX := .a
TARGET_SHARED_LIB_SUFFIX := .so
TARGET_EXE_SUFFIX :=

ifneq ("$(TARGET_OS_FLAVOUR)","")
  -include $(BUILD_SYSTEM)/targets/$(TARGET_OS)/$(TARGET_OS_FLAVOUR)/setup.mk
endif

TARGET_LIBC ?= eglibc
