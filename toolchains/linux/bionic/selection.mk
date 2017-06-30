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

ifeq ("$(TARGET_USE_CLANG)","1")
  # Requires NDK r14b or newer, use new scripts, new args, and new toolchain

  # TARGET_ANDROID_TOOLCHAIN_VERSION & TARGET_ANDROID_TOOLCHAIN are ignored as
  # newer NDKs only have one toolchain anyway.

  ANDROID_TOOLCHAIN_SCRIPT := $(TARGET_ANDROID_NDK)/build/tools/make_standalone_toolchain.py
  ANDROID_TOOLCHAIN_OPTIONS := \
	--api=$(TARGET_ANDROID_MINAPILEVEL) \
	--arch=$(ANDROID_ARCH) \
	--install-dir=$(ANDROID_TOOLCHAIN_PATH) \
	--stl=$(TARGET_ANDROID_STL) \
	--unified-headers
  ANDROID_TOOLCHAIN_TOKEN := $(ANDROID_TOOLCHAIN_PATH)/$(TARGET_ANDROID_TOOLCHAIN).android-$(TARGET_ANDROID_MINAPILEVEL)-unified-headers

else
  # Legacy mode

  # On ndk before r15 use the legacy code below
  ifneq ("$(firstword $(sort $(ANDROID_NDK_MAJOR_VERSION) 15))", "15")

    # Choose Toolchain
    ifndef TARGET_ANDROID_TOOLCHAIN_VERSION
      TARGET_ANDROID_TOOLCHAIN_VERSION := \
	$(shell ANDROID_NDK_ROOT=$(TARGET_ANDROID_NDK) . $(TARGET_ANDROID_NDK)/build/tools/dev-defaults.sh && \
		echo $$(get_default_gcc_version_for_arch $(ANDROID_ARCH)))
    endif
    ifndef TARGET_ANDROID_TOOLCHAIN
      TARGET_ANDROID_TOOLCHAIN := \
	$(shell ANDROID_NDK_ROOT=$(TARGET_ANDROID_NDK) . $(TARGET_ANDROID_NDK)/build/tools/dev-defaults.sh && \
		echo $$(get_toolchain_name_for_arch $(ANDROID_ARCH) $(TARGET_ANDROID_TOOLCHAIN_VERSION)))
    endif
    ifeq ("$(TARGET_ANDROID_TOOLCHAIN)","")
      $(error Failed to detect Android toolchain, set the name of the toolchain in the TARGET_ANDROID_TOOLCHAIN variable)
    endif

    ANDROID_TOOLCHAIN_SCRIPT := $(TARGET_ANDROID_NDK)/build/tools/make-standalone-toolchain.sh
    ANDROID_TOOLCHAIN_OPTIONS := \
	--platform=android-$(TARGET_ANDROID_MINAPILEVEL) \
	--arch=$(ANDROID_ARCH) \
	--install-dir=$(ANDROID_TOOLCHAIN_PATH) \
	--toolchain=$(TARGET_ANDROID_TOOLCHAIN) \
	--stl=$(TARGET_ANDROID_STL)

    ANDROID_TOOLCHAIN_TOKEN := $(ANDROID_TOOLCHAIN_PATH)/$(TARGET_ANDROID_TOOLCHAIN).android-$(TARGET_ANDROID_MINAPILEVEL)

  # For ndk r15, use the new script, but request deprecated (non unified) headers
  else
    ANDROID_TOOLCHAIN_SCRIPT := $(TARGET_ANDROID_NDK)/build/tools/make_standalone_toolchain.py
    ANDROID_TOOLCHAIN_OPTIONS := \
	--api=$(TARGET_ANDROID_MINAPILEVEL) \
	--arch=$(ANDROID_ARCH) \
	--install-dir=$(ANDROID_TOOLCHAIN_PATH) \
	--stl=$(TARGET_ANDROID_STL) \
	--deprecated-headers
    ANDROID_TOOLCHAIN_TOKEN := $(ANDROID_TOOLCHAIN_PATH)/$(TARGET_ANDROID_TOOLCHAIN).android-$(TARGET_ANDROID_MINAPILEVEL)-deprecated-headers
  endif
endif


ifeq ("$(wildcard $(ANDROID_TOOLCHAIN_TOKEN))","")
  $(info Installing Android-$(TARGET_ANDROID_MINAPILEVEL) toolchain $(TARGET_ANDROID_TOOLCHAIN) from NDK)
  $(shell (if [ -e $(ANDROID_TOOLCHAIN_PATH) ] ; then rm -rf $(ANDROID_TOOLCHAIN_PATH); fi ; \
	$(ANDROID_TOOLCHAIN_SCRIPT) $(ANDROID_TOOLCHAIN_OPTIONS) && \
		touch $(ANDROID_TOOLCHAIN_TOKEN)) >&2)
endif

# Find the prefix by listing the toolchain bin directory
ANDROID_TOOLCHAIN_PREFIX := $(shell ls $(ANDROID_TOOLCHAIN_PATH)/bin/*-objdump | sed 's:.*/\(.*\)-objdump.*:\1:')
ifeq ("$(ANDROID_TOOLCHAIN_PREFIX)", "")
  $(error Failed to detect android toolchain prefix)
endif

ifeq ("$(TARGET_USE_CLANG)", "1")
  # Clang mode, do not define TARGET_CROSS but define our own TARGET_tools
  ANDROID_CROSS := $(ANDROID_TOOLCHAIN_PATH)/bin/$(ANDROID_TOOLCHAIN_PREFIX)-
  TARGET_CC ?= $(ANDROID_CROSS)clang
  TARGET_CXX ?= $(ANDROID_CROSS)clang++
  TARGET_AS ?= $(ANDROID_CROSS)as
  TARGET_AR ?= $(ANDROID_CROSS)ar
  TARGET_LD ?= $(ANDROID_CROSS)ld
  TARGET_NM ?= $(ANDROID_CROSS)nm
  TARGET_STRIP ?= $(ANDROID_CROSS)strip
  TARGET_CPP ?= $(ANDROID_CROSS)cpp
  TARGET_RANLIB ?= $(ANDROID_CROSS)ranlib
  TARGET_OBJCOPY ?= $(ANDROID_CROSS)objcopy
  TARGET_OBJDUMP ?= $(ANDROID_CROSS)objdump

  # For Android NDK 15 + clang, we need to add "-fintegrated-as" to the clang CFLAGS
  # (see https://android.googlesource.com/platform/ndk/+/ndk-r15-release/CHANGELOG.md)
  ifeq ("$(ANDROID_NDK_MAJOR_VERSION)", "15")
    ifeq ("$(ANDROID_ARCH)", "mips64")
      TARGET_GLOBAL_CFLAGS += -fintegrated-as
    endif
  endif
else
  # Legacy mode, use TARGET_CROSS
  TARGET_CROSS := $(ANDROID_TOOLCHAIN_PATH)/bin/$(ANDROID_TOOLCHAIN_PREFIX)-
endif

endif
