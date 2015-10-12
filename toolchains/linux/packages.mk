###############################################################################
## @file linux/packages.mk
## @author Y.M. Morgan
## @date 2015/04/10
##
## This file contains package definition specific to linux.
###############################################################################

# Include libc specific packages
include $(BUILD_SYSTEM)/toolchains/$(TARGET_OS)/$(TARGET_LIBC)/packages.mk
