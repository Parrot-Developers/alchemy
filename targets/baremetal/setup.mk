###############################################################################
## @file targets/baremetal/setup.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Setup variables for baremetal target.
###############################################################################

TARGET_STATIC_LIB_SUFFIX := .a
TARGET_SHARED_LIB_SUFFIX := .so.a
TARGET_EXE_SUFFIX := .elf

# Select arm mode only (no thumb) by default
TARGET_DEFAULT_ARM_MODE ?= arm

# Force static compilation
TARGET_FORCE_STATIC := 1
