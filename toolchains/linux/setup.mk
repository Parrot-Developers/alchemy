###############################################################################
## @file linux/setup.mk
## @author Y.M. Morgan
## @date 2015/04/10
##
## This file contains additional setup for linux.
###############################################################################

# Include libc specific setup
include $(BUILD_SYSTEM)/toolchains/$(TARGET_OS)/$(TARGET_LIBC)/setup.mk
