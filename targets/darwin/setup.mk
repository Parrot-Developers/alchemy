###############################################################################
## @file targets/darwin/setup.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Setup variables for darwin target.
###############################################################################

TARGET_STATIC_LIB_SUFFIX := .a
TARGET_SHARED_LIB_SUFFIX := .dylib
TARGET_EXE_SUFFIX :=

TARGET_LIBC := darwin

ifneq ("$(TARGET_OS_FLAVOUR)","")
  -include $(BUILD_SYSTEM)/targets/$(TARGET_OS)/$(TARGET_OS_FLAVOUR)/setup.mk
endif

# Force adding lib prefix to libraries
USE_AUTO_LIB_PREFIX := 1
