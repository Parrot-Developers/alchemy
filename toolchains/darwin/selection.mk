###############################################################################
## @file toolchains/darwin/selection.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Setup toolchain variables.
###############################################################################

ifeq ("$(TARGET_ARCH)","x64")
  APPLE_ARCH := -arch x86_64
  TARGET_TOOLCHAIN_TRIPLET := x86_64-apple-darwin
else ifeq ("$(TARGET_ARCH)","x86")
  APPLE_ARCH := -arch i386
  TARGET_TOOLCHAIN_TRIPLET := i386-apple-darwin
else ifeq ("$(TARGET_ARCH)","arm")
  ifeq ("$(call check-version,$(TARGET_IPHONE_VERSION),11.0)","")
    APPLE_ARCH := -arch armv7 -arch arm64
  else
    APPLE_ARCH := -arch arm64
  endif
  TARGET_TOOLCHAIN_TRIPLET := arm-apple-darwin
endif

TARGET_CROSS ?=

# Avoid using ?= when invoking shell to make sure we have an immediate expansion
ifndef TARGET_CC
  TARGET_CC := $(shell xcrun --find --sdk $(APPLE_SDK) clang)
endif
ifndef TARGET_CXX
  TARGET_CXX := $(shell xcrun --find --sdk $(APPLE_SDK) clang++)
endif
ifndef TARGET_AS
  TARGET_AS := $(shell xcrun --find --sdk $(APPLE_SDK) as)
endif
ifndef TARGET_AR
  TARGET_AR := $(shell xcrun --find --sdk $(APPLE_SDK) ar)
endif
ifndef TARGET_LD
  TARGET_LD := $(shell xcrun --find --sdk $(APPLE_SDK) ld)
endif
ifndef TARGET_NM
  TARGET_NM := $(shell xcrun --find --sdk $(APPLE_SDK) nm)
endif
ifndef TARGET_STRIP
  TARGET_STRIP := $(shell xcrun --find --sdk $(APPLE_SDK) strip)
endif
ifndef TARGET_CPP
  TARGET_CPP := $(shell xcrun --find --sdk $(APPLE_SDK) cpp)
endif
ifndef TARGET_RANLIB
  TARGET_RANLIB := $(shell xcrun --find --sdk $(APPLE_SDK) ranlib)
endif

#TODO: use lipo wrapper....
TARGET_OBJCOPY ?= $(TARGET_CROSS)objcopy
TARGET_OBJDUMP ?= $(TARGET_CROSS)objdump
