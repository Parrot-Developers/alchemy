###############################################################################
## @file envsetup.mk
## @author F. Ferrand
## @date 2015/09/20
###############################################################################

# This script is used from Alchemy, but designed to allow being included from
# other makefile: e.g. to wrap Alchemy but still let it handle architecture
# selection and path mapping.
#
# As a consequence, we need to redefine TOP_DIR, which is normally defined
# by Alchemy earlier in the process.
TOP_DIR ?= $(realpath $(ALCHEMY_WORKSPACE_DIR))

###############################################################################
## Host preliminary setup.
###############################################################################
HOST_OS := $(shell uname -s | awk '{print tolower($$0)}')
HOST_CC ?= gcc

# Architecture
ifndef HOST_ARCH
  ifneq ("$(shell $(HOST_CC) -dumpmachine | grep 64)","")
    HOST_ARCH := x64
  else
    HOST_ARCH := x86
  endif
endif

###############################################################################
## Target OS aliases.
###############################################################################

# TARGET_OS aliases to simplify selection of android/iphone/iphonesimulator targets
ifeq ("$(TARGET_OS)","android")
  override TARGET_OS = linux
  override TARGET_OS_FLAVOUR = android
  TARGET_ARCH ?= arm
else ifeq ("$(TARGET_OS)","parrot")
  override TARGET_OS = linux
  override TARGET_OS_FLAVOUR = parrot
  TARGET_ARCH ?= arm
else ifeq ("$(TARGET_OS)","iphone")
  override TARGET_OS = darwin
  override TARGET_OS_FLAVOUR = iphoneos
  TARGET_ARCH ?= arm
else ifeq ("$(TARGET_OS)","iphonesimulator")
  override TARGET_OS = darwin
  override TARGET_OS_FLAVOUR = iphonesimulator
else ifeq ("$(TARGET_OS)","yocto")
  override TARGET_OS = linux
  override TARGET_OS_FLAVOUR = yocto
  TARGET_ARCH ?= arm
endif

###############################################################################
## Target configuration.
###############################################################################

TARGET_ARCH ?= $(HOST_ARCH)
TARGET_CPU ?=
TARGET_OS ?= $(shell uname -s | awk '{print tolower($$0)}')
TARGET_OS_FLAVOUR ?= native
TARGET_LIBC ?=
TARGET_PRODUCT ?= $(TARGET_OS)-$(TARGET_OS_FLAVOUR)
TARGET_PRODUCT_VARIANT ?= $(TARGET_ARCH)

ifeq ("$(TARGET_PRODUCT_VARIANT)","")
  TARGET_PRODUCT_FULL_NAME := $(TARGET_PRODUCT)
else
  TARGET_PRODUCT_FULL_NAME := $(TARGET_PRODUCT)-$(TARGET_PRODUCT_VARIANT)
endif

# Only TARGET_OUT should be specified, other will be impossible to override in
# future versions
ifneq ("$(TARGET_OUT_BUILD)","")
$(warning TARGET_OUT_BUILD is set, only TARGET_OUT should be specified)
endif
ifneq ("$(TARGET_OUT_STAGING)","")
$(warning TARGET_OUT_STAGING, only TARGET_OUT should be specified)
endif
ifneq ("$(TARGET_OUT_FINAL)","")
$(warning TARGET_OUT_FINAL, only TARGET_OUT should be specified)
endif
ifneq ("$(TARGET_OUT_DOC)","")
$(warning TARGET_OUT_DOC, only TARGET_OUT should be specified)
endif

TARGET_OUT_PREFIX ?= Alchemy-out/
TARGET_OUT ?= $(TOP_DIR)/$(TARGET_OUT_PREFIX)$(TARGET_PRODUCT_FULL_NAME)
TARGET_OUT_BUILD ?= $(TARGET_OUT)/build
TARGET_OUT_DOC ?= $(TARGET_OUT)/doc
TARGET_OUT_STAGING ?= $(TARGET_OUT)/staging
TARGET_OUT_FINAL ?= $(TARGET_OUT)/final
TARGET_OUT_GCOV ?= $(TARGET_OUT)/gcov

TARGET_CONFIG_PREFIX ?= Alchemy-config/
TARGET_CONFIG_DIR ?= $(TOP_DIR)/$(TARGET_CONFIG_PREFIX)$(TARGET_PRODUCT)-$(TARGET_PRODUCT_VARIANT)

# Extra directories to skip/add during makefile scan
TARGET_SCAN_PRUNE_DIRS ?=
TARGET_SCAN_ADD_DIRS ?=

# Ignore config and out directorie(s)
ifneq ("$(dir $(TOP_DIR)/$(TARGET_CONFIG_PREFIX))","$(TOP_DIR)")
TARGET_SCAN_PRUNE_DIRS += $(dir $(TOP_DIR)/$(TARGET_CONFIG_PREFIX))
endif
ifneq ("$(dir $(TOP_DIR)/$(TARGET_OUT_PREFIX))","$(TOP_DIR)")
TARGET_SCAN_PRUNE_DIRS += $(dir $(TOP_DIR)/$(TARGET_OUT_PREFIX))
endif
