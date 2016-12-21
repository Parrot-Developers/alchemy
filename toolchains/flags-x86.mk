###############################################################################
## @file toolchains/flags-x86.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Setup toolchain variables.
###############################################################################

TARGET_GLOBAL_CFLAGS += -m32
TARGET_GLOBAL_LDFLAGS += -m32

TARGET_CPU_HAS_SSE ?= 1
TARGET_CPU_HAS_SSE2 ?= 1
TARGET_CPU_HAS_SSSE3 ?= 1

ifeq ("$(TARGET_CPU_HAS_SSE)","1")
  TARGET_GLOBAL_CFLAGS += -msse
endif
ifeq ("$(TARGET_CPU_HAS_SSE2)","1")
  TARGET_GLOBAL_CFLAGS += -msse2
endif
ifeq ("$(TARGET_CPU_HAS_SSSE3)","1")
  TARGET_GLOBAL_CFLAGS += -mssse3
endif
