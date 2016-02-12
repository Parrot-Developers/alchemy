###############################################################################
## @file check.mk
## @author Y.M. Morgan
## @date 2013/01/28
##
## This file contains some checks.
###############################################################################

###############################################################################
## Check versions of host tools.
###############################################################################

# Need make v3.81 at least (for lastword, info...)
ifeq ("$(call check-version,$(MAKE_VERSION),3.81)","")
  $(error 'make' version >= 3.81 is required)
endif

# Need pkg-config v0.24 at least (for PKG_CONFIG_SYSROOT_DIR support)
# not needed for ecos
ifneq ("$(TARGET_OS)","ecos")
ifneq ("$(TARGET_OS)","baremetal")
ifeq ("$(shell which pkg-config)","")
  $(error 'pkg-config' is required)
endif
PKGCONFIG_VERSION := $(shell pkg-config --version)
ifeq ("$(call check-version,$(PKGCONFIG_VERSION),0.24)","")
  $(error 'pkg-config' version >= 0.24 is required)
endif
endif
endif

###############################################################################
## '-mcpu=cortex-a9' is only supported by gcc >= 4.5
###############################################################################

ifneq ("$(USE_CLANG)","1")
ifeq ("$(call check-version,$(TARGET_CC_VERSION),4.5.0)","")
ifneq ("$(findstring -mcpu=cortex-a9,$(TARGET_GLOBAL_CFLAGS))","")
  $(warning This version of gcc does not support '-mcpu=cortex-a9' option)
  TARGET_GLOBAL_CFLAGS := $(filter-out -mcpu=cortex-a9,$(TARGET_GLOBAL_CFLAGS))
endif
endif
endif
