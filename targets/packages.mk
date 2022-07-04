###############################################################################
## @file targets/packages.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Additional packages for target.
###############################################################################

internal-is-builtin := 1

ifeq ("$(TARGET_OS_FLAVOUR)","native")
  include $(BUILD_SYSTEM)/targets/native-packages.mk
endif
-include $(BUILD_SYSTEM)/targets/$(TARGET_OS)/packages.mk

internal-is-builtin := 0
