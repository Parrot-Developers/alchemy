###############################################################################
## @file targets/ecos/setup.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Setup variables for ecos target.
###############################################################################

TARGET_STATIC_LIB_SUFFIX := .a
TARGET_SHARED_LIB_SUFFIX := .so.a
TARGET_EXE_SUFFIX := .elf

TARGET_LIBC := ecos

# Force arm mode (disable thumb)
TARGET_DEFAULT_ARM_MODE := arm

# Force static compilation
TARGET_FORCE_STATIC := 1
