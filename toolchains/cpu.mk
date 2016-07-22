###############################################################################
## @file toolchains/cpu.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Setup toolchain variables.
###############################################################################

# arm v5te flags (to be used in cpu flags below)
# ecos already set them
ifneq ("$(TARGET_OS)","ecos")
cflags_armv5te := \
	-march=armv5te \
	-D__ARM_ARCH_5__ \
	-D__ARM_ARCH_5T__ \
	-D__ARM_ARCH_5TE__
else
cflags_armv5te :=
endif

# armv7-a neon flags (to be used in cpu flags below)
cflags_armv7a_neon := \
	-march=armv7-a \
	-mfpu=neon

###############################################################################
## Parrot cpus.
###############################################################################

ifeq ("$(TARGET_CPU)","p6")
  TARGET_GLOBAL_CFLAGS += $(cflags_armv5te)
  TARGET_GLOBAL_CFLAGS += -mtune=arm926ej-s -mcpu=arm926ej-s
  TARGET_FLOAT_ABI ?= soft
endif

ifeq ("$(TARGET_CPU)","p6i")
  TARGET_GLOBAL_CFLAGS += $(cflags_armv5te)
  TARGET_GLOBAL_CFLAGS += -mtune=arm926ej-s -mcpu=arm926ej-s
  TARGET_FLOAT_ABI ?= soft
endif

ifeq ("$(TARGET_CPU)","p7")
  TARGET_GLOBAL_CFLAGS += $(cflags_armv7a_neon)
  TARGET_GLOBAL_CFLAGS += -mtune=cortex-a9 -mcpu=cortex-a9
  TARGET_CPU_ARMV7A_NEON := 1
  TARGET_CPU_HAS_NEON := 1
  TARGET_FLOAT_ABI ?= softfp
endif

ifeq ("$(TARGET_CPU)","o3")
  TARGET_GLOBAL_CFLAGS += -march=armv7-a
  TARGET_GLOBAL_CFLAGS += -mtune=cortex-a5 -mcpu=cortex-a5
  TARGET_FLOAT_ABI ?= soft
endif

###############################################################################
# Texas Instrument cpus.
###############################################################################
ifeq ("$(TARGET_CPU)","omap3")
  TARGET_GLOBAL_CFLAGS += $(cflags_armv7a_neon)
  TARGET_GLOBAL_LDFLAGS += -Wl,--fix-cortex-a8
  TARGET_CPU_ARMV7A_NEON := 1
  TARGET_CPU_HAS_NEON := 1
  TARGET_FLOAT_ABI ?= softfp
endif

ifeq ("$(TARGET_CPU)","omap4")
  TARGET_GLOBAL_CFLAGS += $(cflags_armv7a_neon)
  TARGET_GLOBAL_CFLAGS += -mtune=cortex-a9 -mcpu=cortex-a9
  TARGET_CPU_ARMV7A_NEON := 1
  TARGET_CPU_HAS_NEON := 1
  TARGET_FLOAT_ABI ?= softfp
endif

###############################################################################
# Nvidia cpus.
###############################################################################

ifeq ("$(TARGET_CPU)","tegrak1")
ifneq ("$(call check-version,$(TARGET_CC_VERSION),4.9.0)","")
  TARGET_GLOBAL_CFLAGS += -march=armv7ve -mcpu=cortex-a15
else
  TARGET_GLOBAL_CFLAGS += -march=armv7-a
endif
  TARGET_GLOBAL_CFLAGS += -mtune=cortex-a15 -mfpu=neon-vfpv4
  TARGET_CPU_HAS_NEON := 1
  TARGET_FLOAT_ABI ?= hard
  TARGET_GLOBAL_NVCFLAGS += -arch=sm_32 -lineinfo -m32
endif

ifeq ("$(TARGET_CPU)","tegrax1")
  TARGET_GLOBAL_CFLAGS += -march=armv8-a+crc -mtune=cortex-a57 -mcpu=cortex-a57
  TARGET_GLOBAL_CFLAGS += -mfpu=crypto-neon-fp-armv8
  TARGET_CPU_HAS_NEON := 1
  TARGET_FLOAT_ABI ?= hard
  TARGET_GLOBAL_NVCFLAGS += -arch=sm_53 -lineinfo -m32
endif

###############################################################################
# Ambarella cpus
###############################################################################

ifeq ("$(TARGET_CPU)","a9s")
  TARGET_GLOBAL_CFLAGS += $(cflags_armv7a_neon)
  TARGET_GLOBAL_LDFLAGS += -Wl,--fix-cortex-a8
  TARGET_CPU_ARMV7A_NEON := 1
  TARGET_CPU_HAS_NEON := 1
  TARGET_FLOAT_ABI ?= softfp
endif

###############################################################################
# Apq8009 cpus
###############################################################################

ifeq ("$(TARGET_CPU)","apq8009")
  TARGET_GLOBAL_CFLAGS += $(cflags_armv7a_neon)
  TARGET_GLOBAL_CFLAGS += -march=armv7ve -mtune=cortex-a7 -mcpu=cortex-a7
  TARGET_CPU_ARMV7A_NEON := 1
  TARGET_CPU_HAS_NEON := 1
  TARGET_FLOAT_ABI ?= hard
endif

###############################################################################
# Generic cpus.
###############################################################################

ifeq ("$(TARGET_CPU)","armv5te")
  TARGET_GLOBAL_CFLAGS += $(cflags_armv5te)
  TARGET_FLOAT_ABI ?= soft
endif

# generic armv7a (without neon)
ifeq ("$(TARGET_CPU)","armv7a")
  TARGET_GLOBAL_CFLAGS += -march=armv7-a -mfpu=vfpv3-d16
  TARGET_GLOBAL_LDFLAGS += -march=armv7-a -Wl,--fix-cortex-a8
  TARGET_GLOBAL_LDFLAGS_SHARED += -march=armv7-a -Wl,--fix-cortex-a8
  TARGET_FLOAT_ABI ?= soft
endif

# generic armv7a-neon
ifeq ("$(TARGET_CPU)","armv7a-neon")
  TARGET_GLOBAL_CFLAGS += $(cflags_armv7a_neon)
  TARGET_GLOBAL_LDFLAGS += -march=armv7-a -Wl,--fix-cortex-a8
  TARGET_GLOBAL_LDFLAGS_SHARED += -march=armv7-a -Wl,--fix-cortex-a8
  TARGET_CPU_ARMV7A_NEON := 1
  TARGET_CPU_HAS_NEON := 1
  TARGET_FLOAT_ABI ?= softfp
endif

###############################################################################
# Microcontrollers.
###############################################################################

ifeq ("$(TARGET_CPU)","arm7tdmi")
  TARGET_GLOBAL_CFLAGS += -mcpu=arm7tdmi
endif

ifeq ("$(TARGET_CPU)", "stm32f3")
  TARGET_GLOBAL_CFLAGS += -mcpu=cortex-m4 -mfpu=fpv4-sp-d16
  TARGET_GLOBAL_LDFLAGS += -mcpu=cortex-m4 -mfpu=fpv4-sp-d16
  TARGET_FLOAT_ABI ?= hard
endif

ifeq ("$(TARGET_CPU)", "m0")
  TARGET_GLOBAL_CFLAGS += -mcpu=cortex-m0
  TARGET_GLOBAL_LDFLAGS += -mcpu=cortex-m0
  TARGET_FLOAT_ABI ?= soft
endif
