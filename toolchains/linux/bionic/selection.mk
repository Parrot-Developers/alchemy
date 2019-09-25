###############################################################################
## @file toolchains/linux/bionic/selection.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Setup toolchain variables.
###############################################################################

ifndef USE_ALCHEMY_ANDROID_SDK

# Map target arch to android arch
ifeq ("$(TARGET_ARCH)","aarch64")
  ANDROID_ARCH := arm64
else ifeq ("$(TARGET_ARCH)","x64")
  ANDROID_ARCH := x86_64
else
  ANDROID_ARCH := $(TARGET_ARCH)
endif

ANDROID_TOOLCHAIN_PATH := $(TARGET_OUT)/toolchain

# Android ndk version naming rule:
# MAJOR is the ndk number
# MINOR is the ndk letter (0 = no letter, 1 = b, ...)
# Ex: r14b is 14.1, r11c is 11.2, r15 is 15.0
ANDROID_NDK_SOURCE_PROP := $(TARGET_ANDROID_NDK)/source.properties
ANDROID_NDK_VERSION := $(shell test -f $(ANDROID_NDK_SOURCE_PROP) \
			&& grep -o -E '[0-9]+\.[0-9+]' $(ANDROID_NDK_SOURCE_PROP) \
			|| echo '0.0')
ANDROID_NDK_MAJOR_VERSION := $(firstword $(subst ., ,$(ANDROID_NDK_VERSION)))
ANDROID_NDK_MINOR_VERSION := $(word 2,$(subst ., ,$(ANDROID_NDK_VERSION)))

# Alchemy only supports r17 to r20 NDKs
ifneq ("$(firstword $(sort $(ANDROID_NDK_MAJOR_VERSION) 17))", "17")
  $(error NDK $(ANDROID_NDK_VERSION) is too old for this version of Alchemy)
endif
ifeq ("$(firstword $(sort $(ANDROID_NDK_MAJOR_VERSION) 22))", "22")
  $(error NDK $(ANDROID_NDK_VERSION) is too recent for this version of Alchemy)
endif

# r18 or newer requires TARGET_ANDROID_STL to be libc++
ifeq ("$(firstword $(sort $(ANDROID_NDK_MAJOR_VERSION) 18))", "18")
  ifneq ("$(TARGET_ANDROID_STL)","libc++")
    $(error NDK $(ANDROID_NDK_VERSION) requires TARGET_ANDROID_STL to be 'libc++')
  endif
endif

# For r18 and older, use "make standalone toolchains" script
ifneq ("$(firstword $(sort $(ANDROID_NDK_MAJOR_VERSION) 19))", "19")
  ANDROID_TOOLCHAIN_SCRIPT := $(TARGET_ANDROID_NDK)/build/tools/make_standalone_toolchain.py
  ANDROID_TOOLCHAIN_OPTIONS := \
	--api=$(TARGET_ANDROID_MINAPILEVEL) \
	--arch=$(ANDROID_ARCH) \
	--install-dir=$(ANDROID_TOOLCHAIN_PATH) \
	--stl=$(TARGET_ANDROID_STL)

  ANDROID_TOOLCHAIN_TOKEN_SUFFIX := $(ANDROID_TOOLCHAIN_SCRIPT) $(ANDROID_TOOLCHAIN_OPTIONS)
  ANDROID_TOOLCHAIN_TOKEN_SUFFIX := $(shell echo $(ANDROID_TOOLCHAIN_TOKEN_SUFFIX) | md5sum | cut -d' ' -f1)
  ANDROID_TOOLCHAIN_TOKEN := $(ANDROID_TOOLCHAIN_PATH)/$(ANDROID_NDK_VERSION)-$(ANDROID_TOOLCHAIN_TOKEN_SUFFIX)

  ifeq ("$(wildcard $(ANDROID_TOOLCHAIN_TOKEN))","")
    $(info Installing Android-$(TARGET_ANDROID_MINAPILEVEL) toolchain $(TARGET_ANDROID_TOOLCHAIN) from NDK)
    dummy := $(shell (if [ -e $(ANDROID_TOOLCHAIN_PATH) ] ; then rm -rf $(ANDROID_TOOLCHAIN_PATH); fi ; \
	  $(ANDROID_TOOLCHAIN_SCRIPT) $(ANDROID_TOOLCHAIN_OPTIONS) && \
		  echo $(ANDROID_TOOLCHAIN_SCRIPT) $(ANDROID_TOOLCHAIN_OPTIONS) > $(ANDROID_TOOLCHAIN_TOKEN)))
  endif

  # Find the prefix by listing the toolchain bin directory
  ANDROID_TOOLCHAIN_PREFIX := $(shell ls $(ANDROID_TOOLCHAIN_PATH)/bin/*-objdump | sed 's:.*/\(.*\)-objdump.*:\1:')
  ifeq ("$(ANDROID_TOOLCHAIN_PREFIX)", "")
    $(error Failed to detect android toolchain prefix)
  endif

  ANDROID_CROSS_CC := $(ANDROID_TOOLCHAIN_PATH)/bin/$(ANDROID_TOOLCHAIN_PREFIX)-
  ANDROID_CROSS_TOOLS := $(ANDROID_CROSS_CC)
else
  # Map host arch to android cross host arch
  ifeq ("$(HOST_ARCH)","x64")
    ANDROID_HOST_ARCH := x86_64
  else
    ANDROID_HOST_ARCH := $(HOST_ARCH)
  endif
  # Map target arch to android toolchain base
  ifeq ("$(TARGET_ARCH)","arm")
    ifeq ("$(TARGET_CPU)","armv7a")
      ANDROID_CC_BASE := armv7a-linux-androideabi
    else
      ANDROID_CC_BASE := arm-linux-androideabi
    endif
    ANDROID_TOOLCHAIN_BASE := arm-linux-androideabi
  else ifeq ("$(TARGET_ARCH)","aarch64")
    ANDROID_TOOLCHAIN_BASE := aarch64-linux-android
    ANDROID_CC_BASE := $(ANDROID_TOOLCHAIN_BASE)
  else ifeq ("$(TARGET_ARCH)","x86")
    ANDROID_TOOLCHAIN_BASE := i686-linux-android
    ANDROID_CC_BASE := $(ANDROID_TOOLCHAIN_BASE)
  else ifeq ("$(TARGET_ARCH)","x64")
    ANDROID_TOOLCHAIN_BASE := x86_64-linux-android
    ANDROID_CC_BASE := $(ANDROID_TOOLCHAIN_BASE)
  else
    $(error Unsupported target arch $(TARGET_ARCH))
  endif
  ANDROID_CROSS_BASE := $(TARGET_ANDROID_NDK)/toolchains/llvm/prebuilt/$(HOST_OS)-$(ANDROID_HOST_ARCH)/bin/
  ANDROID_CROSS_TOOLS := $(ANDROID_CROSS_BASE)$(ANDROID_TOOLCHAIN_BASE)-
  ANDROID_CROSS_CC := $(ANDROID_CROSS_BASE)$(ANDROID_CC_BASE)$(TARGET_ANDROID_MINAPILEVEL)-
endif

TARGET_CC ?= $(ANDROID_CROSS_CC)clang
TARGET_CXX ?= $(ANDROID_CROSS_CC)clang++
TARGET_AS ?= $(ANDROID_CROSS_TOOLS)as
TARGET_AR ?= $(ANDROID_CROSS_TOOLS)ar
TARGET_LD ?= $(ANDROID_CROSS_TOOLS)ld
TARGET_NM ?= $(ANDROID_CROSS_TOOLS)nm
TARGET_STRIP ?= $(ANDROID_CROSS_TOOLS)strip
ifeq ("$(wildcard $(ANDROID_CROSS_TOOLS)cpp)","")
  TARGET_CPP ?= $(TARGET_CC) -E
else
  TARGET_CPP ?= $(ANDROID_CROSS_TOOLS)cpp
endif
TARGET_RANLIB ?= $(ANDROID_CROSS_TOOLS)ranlib
TARGET_OBJCOPY ?= $(ANDROID_CROSS_TOOLS)objcopy
TARGET_OBJDUMP ?= $(ANDROID_CROSS_TOOLS)objdump

endif
