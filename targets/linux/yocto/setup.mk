###############################################################################
## @file targets/linux/yocto/setup.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Setup variables for linux/yocto target.
###############################################################################

YOCTO_SDK_DEFAULT_PATHS := \
	/opt/poky* \
	~/Library/poky* \
	~/poky*

ifndef TARGET_YOCTO_SDK
TARGET_YOCTO_VERSION ?= 1.8

TARGET_YOCTO_SDK := \
	$(shell for path in $(wildcard $(YOCTO_SDK_DEFAULT_PATHS)) ; do \
			if [ -e $$path/$(TARGET_YOCTO_VERSION) ]; then \
				cd $$path && pwd && break; \
			fi; \
		done \
	)
endif
ifeq ("$(wildcard $(TARGET_YOCTO_SDK))","")
  $(error No Yocto SDK found, you need to set your Yocto SDK path in the TARGET_YOCTO_SDK variable)
endif

# File containing env variables
YOCTO_ENV_FILE := $(wildcard $(TARGET_YOCTO_SDK)/$(TARGET_YOCTO_VERSION)/environment-setup-*-linux)

# Yocto sdk target/host sysroot
YOCTO_SDK_TARGET_SYSROOT := $(shell . $(YOCTO_ENV_FILE) && echo $$SDKTARGETSYSROOT)
YOCTO_SDK_HOST_SYSROOT   := $(shell . $(YOCTO_ENV_FILE) && echo $$OECORE_NATIVE_SYSROOT)

# Get cross toolchain path
YOCTO_TOOLCHAIN_PATH     := $(shell . $(YOCTO_ENV_FILE) && which $$CC | sed 's:/[^/]*$$::')

TARGET_CC      := $(YOCTO_TOOLCHAIN_PATH)/$(shell . $(YOCTO_ENV_FILE) && echo $$CC)
TARGET_CXX     := $(YOCTO_TOOLCHAIN_PATH)/$(shell . $(YOCTO_ENV_FILE) && echo $$CXX)
TARGET_CPP     := $(YOCTO_TOOLCHAIN_PATH)/$(shell . $(YOCTO_ENV_FILE) && echo $$CPP)
TARGET_AS      := $(YOCTO_TOOLCHAIN_PATH)/$(shell . $(YOCTO_ENV_FILE) && echo $$AS)
TARGET_LD      := $(YOCTO_TOOLCHAIN_PATH)/$(shell . $(YOCTO_ENV_FILE) && echo $$LD)
TARGET_STRIP   := $(YOCTO_TOOLCHAIN_PATH)/$(shell . $(YOCTO_ENV_FILE) && echo $$STRIP)
TARGET_RANLIB  := $(YOCTO_TOOLCHAIN_PATH)/$(shell . $(YOCTO_ENV_FILE) && echo $$RANLIB)
TARGET_OBJCOPY := $(YOCTO_TOOLCHAIN_PATH)/$(shell . $(YOCTO_ENV_FILE) && echo $$OBJCOPY)
TARGET_OBJDUMP := $(YOCTO_TOOLCHAIN_PATH)/$(shell . $(YOCTO_ENV_FILE) && echo $$OBJDUMP)
TARGET_AR      := $(YOCTO_TOOLCHAIN_PATH)/$(shell . $(YOCTO_ENV_FILE) && echo $$AR)
TARGET_NM      := $(YOCTO_TOOLCHAIN_PATH)/$(shell . $(YOCTO_ENV_FILE) && echo $$NM)

# Get cross toolchain flags
TARGET_GLOBAL_CFLAGS     += $(shell . $(YOCTO_ENV_FILE) && echo $$CFLAGS)
TARGET_GLOBAL_CXXFLAGS   += $(shell . $(YOCTO_ENV_FILE) && echo $$CXXFLAGS)
TARGET_GLOBAL_LDFLAGS    += $(shell . $(YOCTO_ENV_FILE) && echo $$LDFLAGS)
TARGET_GLOBAL_C_INCLUDES += $(YOCTO_SDK_TARGET_SYSROOT)/usr/include

# Qt variables
TARGET_QMAKE := $(YOCTO_SDK_HOST_SYSROOT)/usr/bin/qt5/qmake
ifneq ("$(wildcard $(TARGET_QMAKE))","")
export OE_QMAKE_CFLAGS    := $(TARGET_GLOBAL_CFLAGS)
export OE_QMAKE_CXXFLAGS  := $(TARGET_GLOBAL_CXXFLAGS)
export OE_QMAKE_LDFLAGS   := $(TARGET_GLOBAL_LDFLAGS)
export OE_QMAKE_CC        := $(TARGET_CC)
export OE_QMAKE_CXX       := $(TARGET_CXX)
export OE_QMAKE_LINK      := $(TARGET_CXX)
export OE_QMAKE_AR        := $(TARGET_AR)
export OE_QMAKE_STRIP     := $(TARGET_STRIP)
export QT_CONF_PATH       := $(shell . $(YOCTO_ENV_FILE) && echo $$QT_CONF_PATH)
export OE_QMAKE_LIBDIR_QT := $(shell . $(YOCTO_ENV_FILE) && echo $$OE_QMAKE_LIBDIR_QT)
export OE_QMAKE_INCDIR_QT := $(shell . $(YOCTO_ENV_FILE) && echo $$OE_QMAKE_INCDIR_QT)
export QMAKESPEC          := $(shell . $(YOCTO_ENV_FILE) && echo $$QMAKESPEC)

TARGET_GLOBAL_C_INCLUDES += $(OE_QMAKE_INCDIR_QT)
endif
