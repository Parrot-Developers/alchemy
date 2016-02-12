###############################################################################
## @file toolchains-setup.mk
## @author Y.M. Morgan
## @date 2012/11/08
##
## This file contains additional setup for toolchains.
###############################################################################

###############################################################################
# Initialize target global variables.
###############################################################################
TARGET_GLOBAL_C_INCLUDES ?=
TARGET_GLOBAL_ASFLAGS ?=
TARGET_GLOBAL_CFLAGS ?=
TARGET_GLOBAL_CXXFLAGS ?=
TARGET_GLOBAL_ARFLAGS ?=
TARGET_GLOBAL_LDFLAGS ?=
TARGET_GLOBAL_LDFLAGS_SHARED ?=
TARGET_GLOBAL_LDLIBS ?=
TARGET_GLOBAL_LDLIBS_SHARED ?=

TARGET_GLOBAL_CFLAGS_gcc ?=
TARGET_GLOBAL_CFLAGS_clang ?=
TARGET_GLOBAL_LDFLAGS_gcc ?=
TARGET_GLOBAL_LDFLAGS_clang ?=
TARGET_GLOBAL_LDFLAGS_SHARED_gcc ?=
TARGET_GLOBAL_LDFLAGS_SHARED_clang ?=

# Pre-compiled header generation flag
TARGET_GLOBAL_PCH_FLAGS ?= -x c++-header

###############################################################################
## Generic setup.
###############################################################################

# Add some generic flags
# -fdata-sections causes issues with some packages
TARGET_GLOBAL_CFLAGS += \
	-pipe \
	-g -O2 \
	-ffunction-sections \
	-fno-short-enums

# TODO: check for these flags
#TARGET_GLOBAL_CFLAGS += \
#	-fpic -fPIE \
#	-funwind-tables \
#	-fstack-protector \
#	-Wa,--noexecstack \

# TODO: check for these flags
#TARGET_GLOBAL_LDFLAGS += \
#	-Wl,-z,noexecstack \
#	-Wl,-z,relro \
#	-Wl,-z,now


ifeq ("$(TARGET_USE_CXX_EXCEPTIONS)","0")
  TARGET_GLOBAL_CXXFLAGS += -fno-exceptions
endif

TARGET_GLOBAL_ARFLAGS += rcs

###############################################################################
## Architecture specific setup.
###############################################################################

ifeq ("$(TARGET_ARCH)","arm")
   include $(BUILD_SYSTEM)/toolchains/arm-setup.mk
endif

ifeq ("$(TARGET_ARCH)","avr")
   include $(BUILD_SYSTEM)/toolchains/avr-setup.mk
endif

ifeq ("$(TARGET_ARCH)","aarch64")
  TARGET_GLOBAL_CFLAGS += -fPIC
endif

ifeq ("$(TARGET_ARCH)","x64")
  TARGET_GLOBAL_CFLAGS += -m64 -fPIC
  TARGET_GLOBAL_LDFLAGS += -m64
  TARGET_GLOBAL_LDFLAGS_SHARED += -m64
endif

ifeq ("$(TARGET_ARCH)","x86")
  TARGET_GLOBAL_CFLAGS += -m32
  TARGET_GLOBAL_LDFLAGS += -m32
  TARGET_GLOBAL_LDFLAGS_SHARED += -m32
endif

###############################################################################
## Linux setup.
###############################################################################
ifeq ("$(TARGET_OS)","linux")

# Default libc is bionic for android, eglibc if not native
ifeq ("$(TARGET_LIBC)","")
  ifeq ("$(TARGET_OS_FLAVOUR)","android")
    TARGET_LIBC := bionic
  else ifeq ("$(TARGET_OS_FLAVOUR)","native")
    TARGET_LIBC := native
  else ifeq ("$(TARGET_OS_FLAVOUR)","native-chroot")
    TARGET_LIBC := native
  else ifeq ("$(TARGET_OS_FLAVOUR)","yocto")
    TARGET_LIBC := yocto
  else
    TARGET_LIBC := eglibc
  endif
endif

# Suffix of output
TARGET_STATIC_LIB_SUFFIX := .a
TARGET_SHARED_LIB_SUFFIX := .so
TARGET_EXE_SUFFIX :=

endif

###############################################################################
## Ecos setup.
###############################################################################
ifeq ("$(TARGET_OS)","ecos")

# Force libc
TARGET_LIBC := ecos

# Suffix of output
TARGET_STATIC_LIB_SUFFIX := .a
TARGET_SHARED_LIB_SUFFIX := .so.a
TARGET_EXE_SUFFIX := .elf

endif

###############################################################################
## Baremetal setup.
###############################################################################
ifeq ("$(TARGET_OS)","baremetal")

# Suffix of output
TARGET_STATIC_LIB_SUFFIX := .a
TARGET_EXE_SUFFIX := .elf

endif

###############################################################################
## MacOS/iOS setup.
###############################################################################
ifeq ("$(TARGET_OS)","darwin")

# Force libc
TARGET_LIBC := darwin

# Prefix of output
TARGET_STATIC_LIB_SUFFIX := .a
TARGET_SHARED_LIB_SUFFIX := .dylib
TARGET_EXE_SUFFIX :=

# Overide various flags
TARGET_GLOBAL_PCH_FLAGS := -x c++-header

endif

###############################################################################
## mingw32 setup.
###############################################################################
ifeq ("$(TARGET_OS)","mingw32")

# Force libc
TARGET_LIBC := mingw32

# Suffix of output
TARGET_STATIC_LIB_SUFFIX := .a
TARGET_SHARED_LIB_SUFFIX := .dll
TARGET_EXE_SUFFIX := .exe

endif

###############################################################################
## Include os specific setup.
###############################################################################

include $(BUILD_SYSTEM)/toolchains/$(TARGET_OS)/setup.mk

###############################################################################
## Tools for target.
###############################################################################

# Make sure TARGET_CROSS is defined (empty by default)
ifndef TARGET_CROSS
  TARGET_CROSS :=
endif

ifneq ("$(USE_CLANG)","1")

TARGET_CC ?= $(TARGET_CROSS)gcc
TARGET_CXX ?= $(TARGET_CROSS)g++
TARGET_AS ?= $(TARGET_CROSS)as
TARGET_AR ?= $(TARGET_CROSS)ar
TARGET_LD ?= $(TARGET_CROSS)ld
TARGET_NM ?= $(TARGET_CROSS)nm
TARGET_STRIP ?= $(TARGET_CROSS)strip
TARGET_CPP ?= $(TARGET_CROSS)cpp
TARGET_RANLIB ?= $(TARGET_CROSS)ranlib
TARGET_OBJCOPY ?= $(TARGET_CROSS)objcopy
TARGET_OBJDUMP ?= $(TARGET_CROSS)objdump

else

# llvm-ar causes issues, so use ar
TARGET_CC ?= clang
TARGET_CXX ?= clang++
ifneq ("$(TARGET_ARCH)","arm")
  TARGET_AS ?= llvm-as
  TARGET_AR ?= ar
  TARGET_LD ?= llvm-ld
  TARGET_NM ?= llvm-nm
  TARGET_STRIP ?= strip
  TARGET_CPP ?= cpp
  TARGET_RANLIB ?= llvm-ranlib
  TARGET_OBJCOPY ?= objcopy
  TARGET_OBJDUMP ?= llvm-objdump
else
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
endif

# No libc or gdbserver by default
TOOLCHAIN_LIBC ?=
TOOLCHAIN_GDBSERVER ?=

TARGET_DEFAULT_BIN_DESTDIR ?= usr/bin
TARGET_DEFAULT_LIB_DESTDIR ?= usr/lib

# Determine compiler path
TARGET_CC_PATH := $(shell which $(TARGET_CC))

# Check compiler path
ifeq ("$(TARGET_CC_PATH)","")
$(error Unable to find compiler: $(TARGET_CC))
endif

# TODO: remove when not used anymore
TARGET_COMPILER_PATH := $(shell PARAM="$(TARGET_CC)";echo $${PARAM%/bin*})

# Machine targetted by toolchain to be used by autotools and libc installation
ifndef TOOLCHAIN_TARGET_NAME
  TOOLCHAIN_TARGET_NAME := $(shell $(TARGET_CC) $(TARGET_GLOBAL_CFLAGS) -print-multiarch 2>&1)
  ifeq ("$(TOOLCHAIN_TARGET_NAME)","")
    TOOLCHAIN_TARGET_NAME := $(shell $(TARGET_CC) $(TARGET_GLOBAL_CFLAGS) -dumpmachine)
  else ifneq ("$(findstring -print-multiarch,$(TOOLCHAIN_TARGET_NAME))","")
    TOOLCHAIN_TARGET_NAME := $(shell $(TARGET_CC) $(TARGET_GLOBAL_CFLAGS) -dumpmachine)
  endif
endif

# Clang uses gcc toochain(libc&binutils) to cross-compile
# The sysroot is the top level one (without subarch like thumb2 for arm)
ifeq ("$(TARGET_OS)","linux")
__toolchain_sysroot := $(shell $(TARGET_CROSS)gcc $(TARGET_GLOBAL_CFLAGS) -print-sysroot)
__toolchain_root := $(shell PARAM=$(TARGET_CC_PATH); echo $${PARAM%/bin*})
TARGET_GLOBAL_CFLAGS_clang += --sysroot=$(__toolchain_sysroot) \
	-target $(TOOLCHAIN_TARGET_NAME) -B $(__toolchain_root)
TARGET_GLOBAL_LDFLAGS_clang += --sysroot=$(__toolchain_sysroot) \
	-target $(TOOLCHAIN_TARGET_NAME) -B $(__toolchain_root)
TARGET_GLOBAL_LDFLAGS_SHARED_clang += --sysroot=$(__toolchain_sysroot) \
	-target $(TOOLCHAIN_TARGET_NAME) -B $(__toolchain_root)
endif

# Determine compiler version
TARGET_CC_VERSION := $(shell $(TARGET_CC) -dumpversion)

# Remove warning about mangling changes of va_list in gcc 4.4 for arm
ifeq ("$(TARGET_ARCH)","arm")
ifneq ("$(call check-version,$(TARGET_CC_VERSION),4.4.0)","")
TARGET_GLOBAL_CXXFLAGS += \
	-Wno-psabi
endif
endif

# retrieve the path to the target's loader
$(shell rm -f a.out)
ifeq ("$(TARGET_OS)","linux")
ifneq ("$(TARGET_OS_FLAVOUR)","android")
TARGET_LOADER := $(shell sh -c " \
	mkdir -p $(TARGET_OUT_BUILD); \
	echo 'int main;' | \
	$(TARGET_CC) $(TARGET_GLOBAL_CFLAGS) -o $(TARGET_OUT_BUILD)/a.out -xc -; \
	readelf -l $(TARGET_OUT_BUILD)/a.out | \
	grep 'interpreter:' | \
	sed 's/.*: \\(.*\\)\\]/\\1/g'; \
	rm -f $(TARGET_OUT_BUILD)/a.out")
endif
endif
TARGET_LOADER ?=
