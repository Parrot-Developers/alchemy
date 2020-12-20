###############################################################################
## @file targets/setup.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Setup variables for target.
###############################################################################

# Default OS if not set is host native
TARGET_OS ?= $(HOST_OS)
ifndef TARGET_OS_FLAVOUR
  ifeq ("$(TARGET_OS)","$(HOST_OS)")
    TARGET_OS_FLAVOUR := native
  else
    TARGET_OS_FLAVOUR :=
  endif
endif

# OS specific setup
-include $(BUILD_SYSTEM)/targets/$(TARGET_OS)/setup.mk

# Default arch if not set is host arch
ifeq ("$(TARGET_OS)","$(HOST_OS)")
  TARGET_ARCH ?= $(HOST_ARCH)
  ifeq ("$(TARGET_OS_FLAVOUR)","native")
    TARGET_LIBC ?= native
  endif
endif
ifndef TARGET_ARCH
  $(error unspecified TARGET_ARCH)
endif
TARGET_LIBC ?=
TARGET_CPU ?=

ifeq ("$(TARGET_OS_FLAVOUR)","")
  TARGET_PRODUCT ?= $(TARGET_OS)
else
  TARGET_PRODUCT ?= $(TARGET_OS)-$(TARGET_OS_FLAVOUR)
endif
TARGET_PRODUCT_VARIANT ?= $(TARGET_ARCH)

ifeq ("$(TARGET_PRODUCT_VARIANT)","")
  TARGET_PRODUCT_FULL_NAME := $(TARGET_PRODUCT)
else
  TARGET_PRODUCT_FULL_NAME := $(TARGET_PRODUCT)-$(TARGET_PRODUCT_VARIANT)
endif

TARGET_STATIC_LIB_SUFFIX ?= .a
TARGET_SHARED_LIB_SUFFIX ?= .so
TARGET_EXE_SUFFIX ?=
TARGET_NO_UNDEFINED ?= 1

# The root for deployment
ifdef TARGET_DEPLOY_ROOT
  TARGET_ROOT_DESTDIR := $(call remove-slash,$(TARGET_DEPLOY_ROOT))
else
  TARGET_ROOT_DESTDIR ?= usr
endif

ifeq ("$(TARGET_ROOT_DESTDIR)","")
  $(error TARGET_ROOT_DESTDIR is empty)
endif

# 'bin', 'lib', 'etc' directories
TARGET_DEFAULT_BIN_DESTDIR ?= $(TARGET_ROOT_DESTDIR)/bin
TARGET_DEFAULT_LIB_DESTDIR ?= $(TARGET_ROOT_DESTDIR)/lib
ifeq ("$(TARGET_ROOT_DESTDIR)","usr")
  # The 'etc' directory is NOT put under 'usr' by default, but as sibling
  TARGET_DEFAULT_ETC_DESTDIR ?= etc
else
  TARGET_DEFAULT_ETC_DESTDIR ?= $(TARGET_ROOT_DESTDIR)/etc
endif
