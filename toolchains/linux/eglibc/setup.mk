###############################################################################
## @file linux/eglibc/setup.mk
## @author Y.M. Morgan
## @date 2012/11/05
##
## This file contains additional setup for eglibc.
###############################################################################

# Select a default toolchain
ifndef TARGET_CROSS
  ifeq ("$(TARGET_ARCH)","arm")
    ifeq ("$(TARGET_CPU)","p6")
      TARGET_CROSS := /opt/arm-2009q1/bin/arm-none-linux-gnueabi-
    else ifeq ("$(TARGET_CPU)","p6i")
      TARGET_CROSS := /opt/arm-2009q1/bin/arm-none-linux-gnueabi-
    else ifeq ("$(TARGET_CPU)","o3")
      TARGET_CROSS := /opt/arm-2015.02-ct-ng/bin/arm-unknown-linux-gnueabi-
    else
      TARGET_CROSS := /opt/arm-2012.03/bin/arm-none-linux-gnueabi-
    endif
  else ifeq ("$(TARGET_ARCH)","aarch64")
      TARGET_CROSS := /opt/arm-2014.11-aarch64-linaro/bin/aarch64-linux-gnu-
  endif
endif

# Machine targetted by toolchain to be used by autotools
# Use a name that will force autotools to believe we are cross-compiling
ifeq ("$(TARGET_ARCH)","x64")
  GNU_TARGET_NAME := x86_64-none-linux-gnu
else ifeq ("$(TARGET_ARCH)","x86")
  GNU_TARGET_NAME := i686-none-linux-gnu
endif

# Assume everybody will wants this
TARGET_GLOBAL_LDLIBS += -pthread -lrt
TARGET_GLOBAL_LDLIBS_SHARED += -pthread -lrt
TARGET_GLOBAL_CFLAGS += -funwind-tables

# Gcc sysroot
# We use cflags as well as arm/thumb mode to select correct variant
gcc-sysroot-flags := $(TARGET_GLOBAL_CFLAGS)
ifeq ("$(TARGET_ARCH)","arm")
  gcc-sysroot-flags += $(TARGET_GLOBAL_CFLAGS_$(TARGET_DEFAULT_ARM_MODE))
endif
gcc-sysroot := $(shell $(TARGET_CROSS)gcc $(gcc-sysroot-flags) -print-sysroot)

# Get libc/gdbserver to copy
ifneq ("$(wildcard $(gcc-sysroot))","")
  TOOLCHAIN_LIBC := $(gcc-sysroot)
  ifneq ("$(wildcard $(gcc-sysroot)/usr/bin/gdbserver)","")
    TOOLCHAIN_GDBSERVER := $(gcc-sysroot)/usr/bin/gdbserver
  else ifneq ("$(wildcard $(gcc-sysroot)/../bin/gdbserver)","")
    TOOLCHAIN_GDBSERVER := $(gcc-sysroot)/../bin/gdbserver
  else ifneq ("$(wildcard $(gcc-sysroot)/../../bin/gdbserver)","")
    TOOLCHAIN_GDBSERVER := $(gcc-sysroot)/../../bin/gdbserver
  else ifneq ("$(wildcard $(gcc-sysroot)/../debug-root/usr/bin/gdbserver)","")
    TOOLCHAIN_GDBSERVER := $(gcc-sysroot)/../debug-root/usr/bin/gdbserver
  endif
endif
