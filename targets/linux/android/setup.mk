###############################################################################
## @file targets/linux/android/setup.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Setup variables for linux/android target.
###############################################################################

TARGET_LIBC := bionic

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

# Default android arch
TARGET_ARCH ?= arm

# Configuration options
TARGET_ANDROID_APILEVEL ?= 17
TARGET_ANDROID_MINAPILEVEL ?= $(TARGET_ANDROID_APILEVEL)

# Choose SDK
ifndef TARGET_ANDROID_SDK
TARGET_ANDROID_SDK := \
	$(shell for path in $(wildcard $(ANDROID_SDK_DEFAULT_PATHS)) ; do \
			if [ -e $$path/platforms/android-$(TARGET_ANDROID_APILEVEL) ]; then \
				cd $$path && pwd && break; \
			fi; \
		done \
	)
endif

# Choose NDK
ifndef TARGET_ANDROID_NDK
TARGET_ANDROID_NDK := \
	$(shell for path in $(wildcard $(ANDROID_NDK_DEFAULT_PATHS)) ; do \
			if [ -e $$path/platforms/android-$(TARGET_ANDROID_MINAPILEVEL) ]; then \
				cd $$path && pwd && break; \
			fi; \
		done \
	)
endif
ifeq ("$(wildcard $(TARGET_ANDROID_NDK))","")
  $(error No Android NDK found, use Alchemy-raptor package or set your Android NDK path in the TARGET_ANDROID_NDK variable)
endif

# Allow specify the STL implementation to use. Default to GNU libstdc++.
# choices: gnustl, libc++, stlport
TARGET_ANDROID_STL ?= gnustl

# Force adding lib prefix to libraries
USE_AUTO_LIB_PREFIX := 1

# Disable map file generation, it causes linker to crash
USE_LINK_MAP_FILE := 0

# Handle STL link issues: either force static or link with STL's dynamic library
ifneq ("$(TARGET_ANDROID_SHARED_STL)","1")
  TARGET_PBUILD_FORCE_STATIC := 1
endif

# Ensure Android/Arm ABI compatibility. Supported ABIs are
# 	- armeabi when TARGET_CPU=''
# 	- armeabi-v7a when TARGET_CPU='armv7a'
# 	- armeabi-v7a with NEON when TARGET_CPU='armv7a-neon'
# as indicated here: https://developer.android.com/ndk/guides/standalone_toolchain.html#abi
ifndef TARGET_DEFAULT_LIB_DESTDIR
  ifeq ("$(TARGET_ARCH)","arm")
    ifeq ("$(TARGET_CPU)","")
      TARGET_DEFAULT_LIB_DESTDIR := libs/armeabi
    else ifeq ("$(TARGET_CPU)","armv5te")
      TARGET_DEFAULT_LIB_DESTDIR := libs/armeabi
    else ifeq ("$(filter-out armv7a armv7a-neon p7,$(TARGET_CPU))","")
      TARGET_DEFAULT_LIB_DESTDIR := libs/armeabi-v7a
    else
      $(error "Target CPU '${TARGET_CPU}' does not support Android ABI Compatibility for ARM.")
    endif
  else ifeq ("$(TARGET_ARCH)","aarch64")
    TARGET_DEFAULT_LIB_DESTDIR := libs/arm64-v8a
  else ifeq ("$(TARGET_ARCH)","x86")
    TARGET_DEFAULT_LIB_DESTDIR := libs/x86
  else ifeq ("$(TARGET_ARCH)","x64")
    TARGET_DEFAULT_LIB_DESTDIR := libs/x86-64
  else ifeq ("$(TARGET_ARCH)","mips")
    TARGET_DEFAULT_LIB_DESTDIR := libs/mips
  else ifeq ("$(TARGET_ARCH)","mips64")
    TARGET_DEFAULT_LIB_DESTDIR := libs/mips64
  endif
endif

endif
