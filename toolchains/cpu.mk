###############################################################################
## @file toolchains/cpu.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Setup toolchain variables.
###############################################################################

# Note for aarch64:
#   https://gcc.gnu.org/onlinedocs/gcc/AArch64-Options.html
#   Feature crypto implies aes, sha2, and simd, which implies fp


# arm v5te flags (to be used in cpu flags below)
# ecos already set them
ifneq ("$(TARGET_OS)","ecos")
cpu_flags_armv5te := \
	-march=armv5te \
	-D__ARM_ARCH_5__ \
	-D__ARM_ARCH_5T__ \
	-D__ARM_ARCH_5TE__
else
cpu_flags_armv5te :=
endif

# armv7-a neon flags (to be used in cpu flags below)
cpu_flags_armv7a_neon := \
	-march=armv7-a \
	-mfpu=neon

cpu_flags :=

###############################################################################
## Parrot cpus.
###############################################################################

ifeq ("$(TARGET_CPU)","p6")
  cpu_flags += $(cpu_flags_armv5te)
  cpu_flags += -mtune=arm926ej-s -mcpu=arm926ej-s
  TARGET_FLOAT_ABI ?= soft
endif

ifeq ("$(TARGET_CPU)","p6i")
  cpu_flags += $(cpu_flags_armv5te)
  cpu_flags += -mtune=arm926ej-s -mcpu=arm926ej-s
  TARGET_FLOAT_ABI ?= soft
endif

ifeq ("$(TARGET_CPU)","p7")
  cpu_flags += $(cpu_flags_armv7a_neon)
  cpu_flags += -mtune=cortex-a9 -mcpu=cortex-a9
  TARGET_CPU_ARMV7A_NEON := 1
  TARGET_CPU_HAS_NEON := 1
  TARGET_FLOAT_ABI ?= softfp
endif

ifeq ("$(TARGET_CPU)","o3")
  cpu_flags += -march=armv7-a
  cpu_flags += -mtune=cortex-a5 -mcpu=cortex-a5
  TARGET_FLOAT_ABI ?= soft
endif

###############################################################################
# Texas Instrument cpus.
###############################################################################

ifeq ("$(TARGET_CPU)","omap3")
  cpu_flags += $(cpu_flags_armv7a_neon)
  TARGET_GLOBAL_LDFLAGS += -Wl,--fix-cortex-a8
  TARGET_CPU_ARMV7A_NEON := 1
  TARGET_CPU_HAS_NEON := 1
  TARGET_FLOAT_ABI ?= softfp
endif

ifeq ("$(TARGET_CPU)","omap4")
  cpu_flags += $(cpu_flags_armv7a_neon)
  cpu_flags += -mtune=cortex-a9 -mcpu=cortex-a9
  TARGET_CPU_ARMV7A_NEON := 1
  TARGET_CPU_HAS_NEON := 1
  TARGET_FLOAT_ABI ?= softfp
endif

###############################################################################
# Ambarella cpus
###############################################################################

ifeq ("$(TARGET_CPU)","h22")
  TARGET_CPU_HAS_NEON := 1
  ifeq ("$(TARGET_ARCH)","aarch64")
    cpu_flags += -march=armv8-a+crc+crypto -mtune=cortex-a53
  else
    cpu_flags += -march=armv8-a+crc -mtune=cortex-a53
    cpu_flags += -mfpu=crypto-neon-fp-armv8
    TARGET_FLOAT_ABI ?= hard
  endif
endif

###############################################################################
# Qualcomm cpus.
###############################################################################

ifeq ("$(TARGET_CPU)","apq8009")
  cpu_flags += $(cpu_flags_armv7a_neon)
  cpu_flags += -march=armv7ve -mtune=cortex-a7 -mcpu=cortex-a7
  TARGET_CPU_ARMV7A_NEON := 1
  TARGET_CPU_HAS_NEON := 1
  TARGET_FLOAT_ABI ?= hard
endif

ifeq ("$(TARGET_CPU)","apq8053")
  cpu_flags += -march=armv8-a+crc -mtune=cortex-a53
  TARGET_CPU_HAS_NEON := 1
  ifneq ("$(TARGET_ARCH)","aarch64")
    cpu_flags += -mfpu=crypto-neon-fp-armv8
    TARGET_FLOAT_ABI ?= hard
  endif
endif

ifeq ("$(TARGET_CPU)","apq8096")
  cpu_flags += -march=armv8-a+crc
  TARGET_CPU_HAS_NEON := 1
  ifneq ("$(TARGET_ARCH)","aarch64")
    cpu_flags += -mfpu=crypto-neon-fp-armv8
    TARGET_FLOAT_ABI ?= hard
  endif
endif

###############################################################################
# Hisilicon cpus.
###############################################################################

ifeq ("$(TARGET_CPU)","hi3559")
  cpu_flags += -mcpu=cortex-a73.cortex-a53
  TARGET_CPU_HAS_NEON := 1
  ifneq ("$(TARGET_ARCH)","aarch64")
    TARGET_FLOAT_ABI ?= hard
  endif
endif

ifeq ("$(TARGET_CPU)","hi3559-a53")
  cpu_flags += -mcpu=cortex-a53
  TARGET_CPU_HAS_NEON := 1
  ifneq ("$(TARGET_ARCH)","aarch64")
    TARGET_FLOAT_ABI ?= hard
  endif
endif

ifeq ("$(TARGET_CPU)","hi3559-m7")
  cpu_flags += -march=armv7e-m -mtune=cortex-m7
  cpu_flags += -mfpu=fpv4-sp-d16
  TARGET_DEFAULT_ARM_MODE ?= thumb
  TARGET_FLOAT_ABI ?= hard
endif

###############################################################################
# Generic cpus.
###############################################################################

ifeq ("$(TARGET_CPU)","armv5te")
  cpu_flags += $(cpu_flags_armv5te)
  TARGET_FLOAT_ABI ?= soft
endif

# generic armv7a (without neon)
ifeq ("$(TARGET_CPU)","armv7a")
  cpu_flags += -march=armv7-a -mfpu=vfpv3-d16
  TARGET_FLOAT_ABI ?= soft
endif

# generic armv7a-neon
ifeq ("$(TARGET_CPU)","armv7a-neon")
  cpu_flags += $(cpu_flags_armv7a_neon)
  TARGET_GLOBAL_LDFLAGS += -Wl,--fix-cortex-a8
  TARGET_CPU_ARMV7A_NEON := 1
  TARGET_CPU_HAS_NEON := 1
  TARGET_FLOAT_ABI ?= softfp
endif

# aarch64 has neon support, unless specifically set to the contrary
ifeq ("$(TARGET_ARCH)","aarch64")
  TARGET_CPU_HAS_NEON ?= 1
endif

###############################################################################
# Microcontrollers.
###############################################################################

ifeq ("$(TARGET_CPU)","arm7tdmi")
  cpu_flags += -mcpu=arm7tdmi
endif

ifeq ("$(TARGET_CPU)", "cortex-m0")
  cpu_flags += -mcpu=cortex-m0
  TARGET_DEFAULT_ARM_MODE ?= thumb
  TARGET_FLOAT_ABI ?= soft
endif

ifeq ("$(TARGET_CPU)", "cortex-m0plus")
  cpu_flags += -mcpu=cortex-m0plus
  TARGET_DEFAULT_ARM_MODE ?= thumb
  TARGET_FLOAT_ABI ?= soft
endif

ifeq ("$(TARGET_CPU)", "cortex-m3")
  cpu_flags += -mcpu=cortex-m3
  TARGET_DEFAULT_ARM_MODE ?= thumb
  TARGET_FLOAT_ABI ?= soft
endif

ifeq ("$(TARGET_CPU)", "cortex-m4-fpu")
  cpu_flags += -mcpu=cortex-m4 -mfpu=fpv4-sp-d16
  TARGET_DEFAULT_ARM_MODE ?= thumb
  TARGET_FLOAT_ABI ?= hard
endif

###############################################################################
###############################################################################

TARGET_GLOBAL_CFLAGS += $(cpu_flags)
TARGET_GLOBAL_LDFLAGS += $(cpu_flags)

# Set float abi
ifdef TARGET_FLOAT_ABI
  ifneq ("$(TARGET_ARCH)","aarch64")
    TARGET_GLOBAL_CFLAGS += -mfloat-abi=$(TARGET_FLOAT_ABI)
    TARGET_GLOBAL_LDFLAGS += -mfloat-abi=$(TARGET_FLOAT_ABI)
  endif
endif
