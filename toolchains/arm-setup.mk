###############################################################################
## @file arm-setup.mk
## @author Y.M. Morgan
## @date 2012/11/08
##
## This file contains additional setup for arm toolchain.
###############################################################################

# Use thumb mode by default
# TODO: is it necessary/usefull/wise ?
TARGET_DEFAULT_ARM_MODE ?= thumb

# Allow mix thumb/arm mode
ifneq ("$(TARGET_OS)","ecos")
ifneq ("$(TARGET_OS)","baremetal")
ifneq ("$(TARGET_DEFAULT_ARM_MODE)","arm")
  TARGET_GLOBAL_CFLAGS_gcc += -mthumb-interwork
# This flag seems unnecessary for post v5 arch and eabi (aapcs)
# Clang does not support it, and, yet, produces interworkable code.
endif
endif
endif

# Required for compilation of shared libraries
ifneq ("$(TARGET_OS)","ecos")
ifneq ("$(TARGET_OS)","baremetal")
  TARGET_GLOBAL_CFLAGS += -fPIC
endif
endif

# arm v5te flags (to be used in cpu flags below)
ifneq ("$(TARGET_OS)","ecos")
ifneq ("$(TARGET_OS)","baremetal")
cflags_armv5te := \
	-march=armv5te \
	-D__ARM_ARCH_5__ \
	-D__ARM_ARCH_5T__ \
	-D__ARM_ARCH_5TE__
else
cflags_armv5te :=
endif
endif

# armv7-a neon flags (to be used in cpu flags below)
cflags_armv7a_neon := \
	-march=armv7-a \
	-mfpu=neon

###############################################################################
## Setup cpu flags.
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

ifeq ("$(TARGET_CPU)","armv5te")
  TARGET_GLOBAL_CFLAGS += $(cflags_armv5te)
  TARGET_FLOAT_ABI ?= soft
endif

# If compiler does not support this -mcpu option a warning will be generated
# and removed from flags later
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

# TODO: see if interresting to put -mtune=cortex-a8 -mcpu=cortex-a8
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

# generic armv7a-neon
ifeq ("$(TARGET_CPU)","armv7a-neon")
  TARGET_GLOBAL_CFLAGS += $(cflags_armv7a_neon)
  TARGET_GLOBAL_LDFLAGS += -Wl,--fix-cortex-a8
  TARGET_CPU_ARMV7A_NEON := 1
  TARGET_CPU_HAS_NEON := 1
  TARGET_FLOAT_ABI ?= softfp
endif

ifeq ("$(TARGET_CPU)","tegrak1")
# TARGET_CC_VERSION is not yet defined
ifneq ("$(call check-version,$(shell $(TARGET_CROSS)gcc -dumpversion),4.9.0)","")
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

ifeq ("$(TARGET_CPU)","arm7tdmi")
  TARGET_GLOBAL_CFLAGS += -mcpu=arm7tdmi
endif

# set float abi
ifdef TARGET_FLOAT_ABI
  TARGET_GLOBAL_CFLAGS += -mfloat-abi=$(TARGET_FLOAT_ABI)
endif

###############################################################################
## Arm/thumb mode flags.
## Taken from Android build system setup.
###############################################################################

# Arm mode specific flags
TARGET_GLOBAL_CFLAGS_arm ?= \
	-marm \
	-O2 \
	-fomit-frame-pointer \
	-fstrict-aliasing

TARGET_GLOBAL_CFLAGS_arm_gcc ?= \
	-finline-limit=300 \
	-funswitch-loops

# Thumb mode specific flags
ifneq ("$(TARGET_DEFAULT_ARM_MODE)","arm")
TARGET_GLOBAL_CFLAGS_thumb ?= \
	-mthumb \
	-Os \
	-fomit-frame-pointer \
	-fno-strict-aliasing

TARGET_GLOBAL_CFLAGS_thumb_gcc ?= -finline-limit=64
TARGET_GLOBAL_CFLAGS_thumb_clang ?=

else
# Make sure that if in arm mode, the thumb flags will not be used
override TARGET_GLOBAL_CFLAGS_thumb :=
override TARGET_GLOBAL_CFLAGS_thumb_gcc :=
override TARGET_GLOBAL_CFLAGS_thumb_clang :=
endif
