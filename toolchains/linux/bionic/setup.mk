###############################################################################
## @file linux/bionic/setup.mk
## @author Y.M. Morgan
## @date 2012/10/18
##
## This file contains additional setup for bionic (android).
###############################################################################

ifndef USE_ALCHEMY_ANDROID_SDK

ANDROID_NDK_DEFAULT_PATHS := \
	/opt/android-ndk-* \
	/opt/android/ndk-* \
	~/Library/Android/android-ndk-* \
	~/android-ndk-*

ANDROID_SDK_DEFAULT_PATHS := \
	/opt/android-sdk* \
	/opt/android/sdk* \
	~/Library/Android/sdk* \
	~/Library/Android/android-sdk* \
	~/android-sdk*

# Map target arch to android arch
ifeq ("$(TARGET_ARCH)","aarch64")
  ANDROID_ARCH := arm64
else ifeq ("$(TARGET_ARCH)","x64")
  ANDROID_ARCH := x86_64
else
  ANDROID_ARCH := $(TARGET_ARCH)
endif

# Configuration options
TARGET_ANDROID_APILEVEL ?= 17

TARGET_ANDROID_SDK ?= \
	$(shell shopt -s nullglob ; \
		for path in $(ANDROID_SDK_DEFAULT_PATHS) ; do \
			if [ -e $$path/platforms/android-$(TARGET_ANDROID_APILEVEL) ]; then \
				cd $$path && pwd && break; \
			fi; \
		done \
	)
ifeq ("$(wildcard $(TARGET_ANDROID_SDK))","")
  $(error No Android SDK found, use Alchemy-raptor package or set your Android SDK path in the TARGET_ANDROID_SDK variable)
endif

TARGET_ANDROID_NDK ?= \
	$(shell shopt -s nullglob ; \
		for path in $(ANDROID_NDK_DEFAULT_PATHS) ; do \
			if [ -e $$path/platforms/android-$(TARGET_ANDROID_APILEVEL) ]; then \
				cd $$path && pwd && break; \
			fi; \
		done \
	)
ifeq ("$(wildcard $(TARGET_ANDROID_NDK))","")
  $(error No Android NDK found, use Alchemy-raptor package or set your Android NDK path in the TARGET_ANDROID_NDK variable)
endif

TARGET_ANDROID_TOOLCHAIN ?= \
	$(shell . $(TARGET_ANDROID_NDK)/build/tools/dev-defaults.sh && \
		echo $$(get_default_toolchain_name_for_arch $(ANDROID_ARCH)))
ifeq ("$(TARGET_ANDROID_TOOLCHAIN)","")
  $(error Failed to detect Android toolchain, set the name of the toolchain in the TARGET_ANDROID_TOOLCHAIN variable)
endif

# Allow specify the STL implementation to use. Default to GNU libstdc++.
TARGET_ANDROID_STL ?= gnustl

# Handle STL link issues: either force static or link with STL's dynamic library
ifneq ("$(TARGET_ANDROID_SHARED_STL)","1")
  TARGET_PBUILD_FORCE_STATIC := 1
else ifeq ("$(TARGET_ANDROID_STL)","gnustl")
  TARGET_GLOBAL_LDFLAGS += -lgnustl_shared
  TARGET_GLOBAL_LDFLAGS_SHARED += -lgnustl_shared
else ifeq ("$(TARGET_ANDROID_STL)","libc++")
  TARGET_GLOBAL_LDFLAGS += -lc++_shared
  TARGET_GLOBAL_LDFLAGS_SHARED += -lc++_shared
else ifeq ("$(TARGET_ANDROID_STL)","stlport")
  TARGET_GLOBAL_LDFLAGS += -lstlport_shared
  TARGET_GLOBAL_LDFLAGS_SHARED += -lstlport_shared
else
  $(error Unsupported Android STL version. Supported STL versions are: libgnustl, libc++, stlport.)
endif

# Install the android toolchain in output folder
# NOTE: We must copy the toolchain here, before toolchains-setup.mk verifies the compiler is properly setup
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

ifeq ("$(TARGET_ARCH)","arm")
  TARGET_DEFAULT_LIB_DESTDIR ?= libs/armeabi-v7a
else ifeq ("$(TARGET_ARCH)","aarch64")
  TARGET_DEFAULT_LIB_DESTDIR ?= libs/arm64-v8a
else ifeq ("$(TARGET_ARCH)","x86")
  TARGET_DEFAULT_LIB_DESTDIR ?= libs/x86
else ifeq ("$(TARGET_ARCH)","x64")
  TARGET_DEFAULT_LIB_DESTDIR ?= libs/x86-64
else ifeq ("$(TARGET_ARCH)","mips")
  TARGET_DEFAULT_LIB_DESTDIR ?= libs/mips
else ifeq ("$(TARGET_ARCH)","mips64")
  TARGET_DEFAULT_LIB_DESTDIR ?= libs/mips64
endif

# Force adding lib prefix to libraries
USE_AUTO_LIB_PREFIX := 1

# Disable map file generation, it causes linker to crash
USE_LINK_MAP_FILE := 0

# Needed by some modules
TARGET_GLOBAL_CFLAGS += -DANDROID -DANDROID_NDK

else # USE_ALCHEMY_ANDROID_SDK

# Flags shall be given through environment as they are very, very android
# specific and hard to extract.

TARGET_GLOBAL_C_INCLUDES += \
	$(BUILD_SYSTEM)/toolchains/linux/bionic/include

endif
