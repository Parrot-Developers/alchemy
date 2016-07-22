###############################################################################
## @file toolchains/windows/flags-arm.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Setup toolchain variables.
###############################################################################

# Use thumb mode by default
# TODO: is it necessary/usefull/wise ?
TARGET_DEFAULT_ARM_MODE ?= thumb

# Allow mix thumb/arm mode
# This flag seems unnecessary for post v5 arch and eabi (aapcs)
# Clang does not support it, and, yet, produces interworkable code.
ifneq ("$(TARGET_DEFAULT_ARM_MODE)","arm")
  TARGET_GLOBAL_CFLAGS_gcc += -mthumb-interwork
endif

# Required for compilation of shared libraries
ifneq ("$(TARGET_OS)","ecos")
ifneq ("$(TARGET_OS)","baremetal")
  TARGET_GLOBAL_CFLAGS += -fPIC
endif
endif

# Remove warning about mangling changes of va_list in gcc 4.4 for arm
ifneq ("$(call check-version,$(TARGET_CC_VERSION),4.4.0)","")
  TARGET_GLOBAL_CXXFLAGS += -Wno-psabi
endif

# Set float abi
ifdef TARGET_FLOAT_ABI
  TARGET_GLOBAL_CFLAGS += -mfloat-abi=$(TARGET_FLOAT_ABI)
  TARGET_GLOBAL_LDFLAGS += -mfloat-abi=$(TARGET_FLOAT_ABI)
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
TARGET_GLOBAL_CFLAGS_arm_clang ?=

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

