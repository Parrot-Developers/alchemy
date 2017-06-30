###############################################################################
## @file toolchains/windows/flags-arm.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Setup toolchain variables.
###############################################################################

# Use thumb mode by default
TARGET_DEFAULT_ARM_MODE ?= thumb

# Default mode for external modules (autotools, cmake...)
# Use arm for compatibility with previous behaviour
TARGET_DEFAULT_ARM_MODE_EXTERNAL ?= arm

# Required for compilation of shared libraries
ifneq ("$(TARGET_OS)","ecos")
ifneq ("$(TARGET_OS)","baremetal")
  TARGET_GLOBAL_CFLAGS += -fPIC
endif
endif

# Remove warning about mangling changes of va_list in gcc 4.4 for arm
ifneq ("$(call check-version,$(TARGET_CC_VERSION),4.4.0)","")
  TARGET_GLOBAL_CXXFLAGS_gcc += -Wno-psabi
endif

###############################################################################
## Arm/thumb mode flags.
## Taken from Android build system setup.
###############################################################################

# Arm mode specific flags
TARGET_GLOBAL_CFLAGS_arm ?= \
	-marm \
	-O2 \
	-fstrict-aliasing

TARGET_GLOBAL_LDFLAGS_arm ?= \
	-marm \
	-O2

# Thumb mode specific flags
ifneq ("$(TARGET_DEFAULT_ARM_MODE)","arm")

TARGET_GLOBAL_CFLAGS_thumb ?= \
	-mthumb \
	-Os \
	-fno-strict-aliasing

TARGET_GLOBAL_LDFLAGS_thumb ?= \
	-mthumb \
	-Os

else

# Make sure that if in arm mode, the thumb flags will not be used
override TARGET_GLOBAL_CFLAGS_thumb :=
override TARGET_GLOBAL_LDFLAGS_thumb :=

endif
