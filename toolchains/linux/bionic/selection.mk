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

# Choose Toolchain
ifndef TARGET_ANDROID_TOOLCHAIN_VERSION
TARGET_ANDROID_TOOLCHAIN_VERSION := \
	$(shell . $(TARGET_ANDROID_NDK)/build/tools/dev-defaults.sh && \
		echo $$(get_default_gcc_version_for_arch $(ANDROID_ARCH)))
endif
ifndef TARGET_ANDROID_TOOLCHAIN
TARGET_ANDROID_TOOLCHAIN := \
	$(shell . $(TARGET_ANDROID_NDK)/build/tools/dev-defaults.sh && \
		echo $$(get_toolchain_name_for_arch $(ANDROID_ARCH) $(TARGET_ANDROID_TOOLCHAIN_VERSION)))
endif
ifeq ("$(TARGET_ANDROID_TOOLCHAIN)","")
  $(error Failed to detect Android toolchain, set the name of the toolchain in the TARGET_ANDROID_TOOLCHAIN variable)
endif

ANDROID_TOOLCHAIN_PATH := $(TARGET_OUT)/toolchain

ANDROID_TOOLCHAIN_OPTIONS := \
	--platform=android-$(TARGET_ANDROID_APILEVEL) \
	--arch=$(ANDROID_ARCH) \
	--install-dir=$(ANDROID_TOOLCHAIN_PATH) \
	--toolchain=$(TARGET_ANDROID_TOOLCHAIN) \
	--stl=$(TARGET_ANDROID_STL)

ANDROID_TOOLCHAIN_TOKEN := $(ANDROID_TOOLCHAIN_PATH)/$(TARGET_ANDROID_TOOLCHAIN).android-$(TARGET_ANDROID_APILEVEL)
ifeq ("$(wildcard $(ANDROID_TOOLCHAIN_TOKEN))","")
$(info Installing Android-$(TARGET_ANDROID_APILEVEL) toolchain $(TARGET_ANDROID_TOOLCHAIN) from NDK)
$(shell (if [ -e $(ANDROID_TOOLCHAIN_PATH) ] ; then rm -rf $(ANDROID_TOOLCHAIN_PATH); fi ; \
	$(TARGET_ANDROID_NDK)/build/tools/make-standalone-toolchain.sh $(ANDROID_TOOLCHAIN_OPTIONS) && \
		touch $(ANDROID_TOOLCHAIN_TOKEN)) >&2)
endif

ANDROID_TOOLCHAIN_NAME := $(shell echo $(TARGET_ANDROID_TOOLCHAIN) | sed 's/\(.*\)-[0-9].[0-9]/\1/')

ifeq ("$(ANDROID_TOOLCHAIN_NAME)","x86")
  ANDROID_TOOLCHAIN_PREFIX := i686-linux-android
else ifeq ("$(ANDROID_TOOLCHAIN_NAME)","x86_64")
  ANDROID_TOOLCHAIN_PREFIX := x86_64-linux-android
else
  ANDROID_TOOLCHAIN_PREFIX := $(ANDROID_TOOLCHAIN_NAME)
endif

TARGET_CROSS := $(ANDROID_TOOLCHAIN_PATH)/bin/$(ANDROID_TOOLCHAIN_PREFIX)-

endif
