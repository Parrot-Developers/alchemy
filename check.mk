###############################################################################
## @file check.mk
## @author Y.M. Morgan
## @date 2013/01/28
##
## This file contains some checks.
###############################################################################

###############################################################################
## Make.
###############################################################################

# Need make v3.81 at least (for lastword, info...)
ifeq ("$(call check-version,$(MAKE_VERSION),3.81)","")
  $(error 'make' version >= 3.81 is required)
endif

# Detect if we have version 4.0 or up
ifneq ("$(call check-version,$(MAKE_VERSION),4.0)","")
  MAKE_HAS_FILE_FUNC := 1
else
  MAKE_HAS_FILE_FUNC := 0
endif

###############################################################################
## pkg-config
## Need pkg-config v0.24 at least (for PKG_CONFIG_SYSROOT_DIR support)
## not needed for ecos or baremetal
###############################################################################

PKGCONFIG_BIN := $(shell which pkg-config 2>/dev/null)

ifneq ("$(TARGET_OS)","ecos")
ifneq ("$(TARGET_OS)","baremetal")
ifeq ("$(PKGCONFIG_BIN)","")
  $(error 'pkg-config' is required)
endif
PKGCONFIG_VERSION := $(shell $(PKGCONFIG_BIN) --version)
ifeq ("$(call check-version,$(PKGCONFIG_VERSION),0.24)","")
  $(error 'pkg-config' version >= 0.24 is required)
endif
endif
endif

###############################################################################
## Bison.
## Use bison from Homebrew by default on MacOS, as Xcode version is too old
## We need bison 2.5 but android force version 2.3 in the path that causes troubles
###############################################################################

ifeq ("$(HOST_OS)","darwin")
  BISON_BIN := $(wildcard /usr/local/opt/bison/bin/bison)
else
  BISON_BIN := $(shell which bison 2>/dev/null)
endif

ifneq ("$(BISON_BIN)","")
  BISON_VERSION := $(shell $(BISON_BIN) --version | head -1 | sed -e 's/.* //g;s/-.*//g')
  ifeq ("$(call check-version,$(BISON_VERSION),2.5)","")
    BISON_BIN := $(wildcard /usr/bin/bison)
    ifneq ("$(BISON_BIN)","")
      BISON_VERSION := $(shell $(BISON_BIN) --version | head -1 | sed -e 's/.* //g;s/-.*//g')
    endif
  endif
endif

# Compatibility
BISON_PATH := $(BISON_BIN)

###############################################################################
## '-mcpu=cortex-a9' is only supported by gcc >= 4.5
###############################################################################

ifeq ("$(TARGET_CC_FLAVOUR)","gcc")
ifeq ("$(call check-version,$(TARGET_CC_VERSION),4.5.0)","")
ifneq ("$(findstring -mcpu=cortex-a9,$(TARGET_GLOBAL_CFLAGS))","")
  $(warning This version of gcc does not support '-mcpu=cortex-a9' option)
  TARGET_GLOBAL_CFLAGS := $(filter-out -mcpu=cortex-a9,$(TARGET_GLOBAL_CFLAGS))
endif
endif
endif

###############################################################################
## check android sdk versions
###############################################################################
ifeq ("$(TARGET_OS_FLAVOUR)","android")
  ifeq ("$(call check-version,$(TARGET_ANDROID_APILEVEL),$(TARGET_ANDROID_MINAPILEVEL))","")
    $(error TARGET_ANDROID_APILEVEL ($(TARGET_ANDROID_APILEVEL)) shall be at least TARGET_ANDROID_MINAPILEVEL ($(TARGET_ANDROID_MINAPILEVEL)))
  endif
endif
