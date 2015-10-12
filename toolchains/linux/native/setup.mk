###############################################################################
## @file linux/native/setup.mk
## @author Y.M. Morgan
## @date 2012/10/18
##
## This file contains additional setup for native linux.
###############################################################################

# Use empty cross compilation flag by default
TARGET_CROSS ?=

# Assume everybody will want this
TARGET_GLOBAL_LDLIBS += -pthread -lrt
TARGET_GLOBAL_LDLIBS_SHARED += -pthread -lrt

# Machine targetted by toolchain to be used by autotools
# Use a name that will force autotools to believe we are cross-compiling
# Do nothing for non chroot native build with TARGET_ARCH = HOST_ARCH
ifeq ("$(TARGET_OS_FLAVOUR)-$(TARGET_ARCH)","native-$(HOST_ARCH)")
  # Leave GNU_TARGET_NAME undefined
else ifeq ("$(TARGET_ARCH)","x64")
  GNU_TARGET_NAME := x86_64-pc-linux-gnu
else ifeq ("$(TARGET_ARCH)","x86")
  GNU_TARGET_NAME := i686-pc-linux-gnu
endif

# Copy host libc
ifeq ("$(TARGET_OS_FLAVOUR)","native-chroot")
  TOOLCHAIN_LIBC := /
endif

TARGET_CPU_HAS_SSE2 := 1
TARGET_CPU_HAS_SSSE3 := 1
# -march=native seems better but this would most likely break distcc builds
TARGET_GLOBAL_CFLAGS += -msse -msse2 -mssse3

# Get gdbserver path if available
TOOLCHAIN_GDBSERVER := $(wildcard /usr/bin/gdbserver)
