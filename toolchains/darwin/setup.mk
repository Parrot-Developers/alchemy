###############################################################################
## @file darwin/setup.mk
## @author F.Ferrand
## @date 2015/04/10
##
## This file contains additional setup for apple toolchains (ios, macos).
###############################################################################

# Options
TARGET_IPHONE_VERSION?=8.2
TARGET_MACOS_VERSION?=10.10

ifeq ("${TARGET_OS_FLAVOUR}","iphoneos")

# iPhone target
APPLE_SDK = iphoneos
APPLE_ARCH = -arch armv7 -arch arm64
APPLE_MINVERSION = -miphoneos-version-min=${TARGET_IPHONE_VERSION}
TARGET_DEFAULT_ARM_MODE = arm
TOOLCHAIN_TARGET_NAME = arm-apple-darwin
TARGET_ARCH = arm
TARGET_PBUILD_FORCE_STATIC := 1

else ifeq ("${TARGET_OS_FLAVOUR}","iphonesimulator")

# iPhoneSimulator target
APPLE_SDK = iphonesimulator

ifeq ("$(TARGET_ARCH)","x86")
  APPLE_ARCH = -arch i386
  TOOLCHAIN_TARGET_NAME = i386-apple-darwin
else
  TARGET_ARCH = x64
  APPLE_ARCH = -arch x86_64
  TOOLCHAIN_TARGET_NAME = x86_64-apple-darwin
endif

APPLE_MINVERSION = -miphoneos-version-min=${TARGET_IPHONE_VERSION}
TARGET_PBUILD_FORCE_STATIC := 1

else ifeq ("${TARGET_OS_FLAVOUR}","native")

# MacOS target
APPLE_SDK = macosx
APPLE_ARCH = -arch x86_64
APPLE_MINVERSION = -mmacosx-version-min=${TARGET_MACOS_VERSION}
TOOLCHAIN_TARGET_NAME = x86_64-apple-darwin
TARGET_ARCH = x64

# Add gettext from HomeBrew
TARGET_GLOBAL_CFLAGS += -I/usr/local/opt/gettext/include
TARGET_GLOBAL_LDFLAGS += -L/usr/local/opt/gettext/lib -lintl

# Need to explicitely link C++ lib on MacOS
TARGET_GLOBAL_LDFLAGS += -lc++

else

$(error "Unsupported Darwin flavour '${TARGET_OS_FLAVOUR}'. Supported flavours: iphoneos, iphonesimulator, native.")

endif

# Setup toolchain
USE_CLANG := 1
ifeq ("$(shell uname)","Darwin")

TARGET_CC ?= $(shell xcrun --find --sdk ${APPLE_SDK} clang)
TARGET_CXX ?= $(shell xcrun --find --sdk ${APPLE_SDK} clang++)
TARGET_AS ?= $(shell xcrun --find --sdk ${APPLE_SDK} as)
TARGET_AR ?= $(ALCHEMY_HOME)/scripts/darwin-ar $(shell xcrun --find --sdk ${APPLE_SDK} ar)
TARGET_LD ?= $(shell xcrun --find --sdk ${APPLE_SDK} ld)
TARGET_NM ?= $(shell xcrun --find --sdk ${APPLE_SDK} nm)
TARGET_STRIP ?= $(shell xcrun --find --sdk ${APPLE_SDK} strip)
TARGET_CPP ?= $(shell xcrun --find --sdk ${APPLE_SDK} cpp)
TARGET_RANLIB ?= $(shell xcrun --find --sdk ${APPLE_SDK} ranlib)
TARGET_OBJCOPY ?= $(TARGET_CROSS)objcopy	#TODO: use lipo wrapper....
TARGET_OBJDUMP ?= $(TARGET_CROSS)objdump	#TODO: use otool wrapper....

else

TARGET_AR ?= $(TARGET_CROSS)ar  			#TODO: use libtool wrapper....
TARGET_OBJCOPY ?= $(TARGET_CROSS)objcopy	#TODO: use lipo wrapper....
TARGET_OBJDUMP ?= $(TARGET_CROSS)objdump	#TODO: use otool wrapper....

endif

# Setup extra flags
TARGET_GLOBAL_CFLAGS += ${APPLE_ARCH} ${APPLE_MINVERSION} -isysroot $(shell xcrun --sdk ${APPLE_SDK} --show-sdk-path)
TARGET_GLOBAL_LDFLAGS += ${APPLE_ARCH} ${APPLE_MINVERSION} -isysroot $(shell xcrun --sdk ${APPLE_SDK} --show-sdk-path)
TARGET_GLOBAL_LDFLAGS_SHARED += ${APPLE_ARCH} ${APPLE_MINVERSION} -isysroot $(shell xcrun --sdk ${APPLE_SDK} --show-sdk-path)

# Force adding lib prefix to libraries
USE_AUTO_LIB_PREFIX := 1
