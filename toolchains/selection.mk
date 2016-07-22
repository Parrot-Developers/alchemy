###############################################################################
## @file toolchains/selection.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Setup toolchain variables.
###############################################################################

ifneq ("$(USE_CLANG)","1")
  HOST_CC ?= cc
  HOST_CXX ?= c++
  HOST_AS ?= as
  HOST_AR ?= ar
  HOST_LD ?= ld
  HOST_NM ?= nm
  HOST_STRIP ?= strip
  HOST_CPP ?= cpp
  HOST_RANLIB ?= ranlib
  HOST_OBJCOPY ?= objcopy
  HOST_OBJDUMP ?= objdump
else
  HOST_CC ?= clang
  HOST_CXX ?= clang++
  HOST_AS ?= llvm-as
  HOST_AR ?= ar
  HOST_LD ?= llvm-ld
  HOST_NM ?= llvm-nm
  HOST_STRIP ?= strip
  HOST_CPP ?= cpp
  HOST_RANLIB ?= llvm-ranlib
  HOST_OBJCOPY ?= objcopy
  HOST_OBJDUMP ?= llvm-objdump
endif

# Select correct toolchain
-include $(BUILD_SYSTEM)/toolchains/$(TARGET_OS)/selection.mk

TARGET_CROSS ?=

ifeq ("$(TARGET_OS)-$(TARGET_OS_FLAVOUR)","$(HOST_OS)-native")
  TARGET_CC ?= $(HOST_CC)
  TARGET_CXX ?= $(HOST_CXX)
  TARGET_AS ?= $(HOST_AS)
  TARGET_AR ?= $(HOST_AR)
  TARGET_LD ?= $(HOST_LD)
  TARGET_NM ?= $(HOST_NM)
  TARGET_STRIP ?= $(HOST_STRIP)
  TARGET_CPP ?= $(HOST_CPP)
  TARGET_RANLIB ?= $(HOST_RANLIB)
  TARGET_OBJCOPY ?= $(HOST_OBJCOPY)
  TARGET_OBJDUMP ?= $(HOST_OBJDUMP)
else
  ifneq ("$(USE_CLANG)","1")
    TARGET_CC ?= $(TARGET_CROSS)gcc
    TARGET_CXX ?= $(TARGET_CROSS)g++
  else
    TARGET_CC ?= clang
    TARGET_CXX ?= clang++
  endif
  TARGET_AS ?= $(TARGET_CROSS)as
  TARGET_AR ?= $(TARGET_CROSS)ar
  TARGET_LD ?= $(TARGET_CROSS)ld
  TARGET_NM ?= $(TARGET_CROSS)nm
  TARGET_STRIP ?= $(TARGET_CROSS)strip
  TARGET_CPP ?= $(TARGET_CROSS)cpp
  TARGET_RANLIB ?= $(TARGET_CROSS)ranlib
  TARGET_OBJCOPY ?= $(TARGET_CROSS)objcopy
  TARGET_OBJDUMP ?= $(TARGET_CROSS)objdump
endif

# Nvidia cuda compiler
TARGET_NVCC ?=

# Determine compiler path
TARGET_CC_PATH := $(shell which $(TARGET_CC) 2>/dev/null)
ifeq ("$(TARGET_CC_PATH)","")
  $(error Unable to find compiler: $(TARGET_CC))
endif

# Determine compiler version
TARGET_CC_VERSION := $(shell $(TARGET_CC) -dumpversion)

# TODO: remove when not used anymore
TARGET_COMPILER_PATH := $(shell PARAM="$(TARGET_CC)";echo $${PARAM%/bin*})

# HOST_CC flavour
ifeq ("$(shell $(HOST_CC) --version | grep -q clang; echo $$?)","0")
  HOST_CC_FLAVOUR := clang
else
  HOST_CC_FLAVOUR := gcc
endif

# TARGET_CC flavour
ifeq ("$(shell $(TARGET_CC) --version | grep -q clang; echo $$?)","0")
  TARGET_CC_FLAVOUR := clang
else
  TARGET_CC_FLAVOUR := gcc
endif
