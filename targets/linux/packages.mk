###############################################################################
## @file targets/linux/packages.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Additional packages for linux target.
###############################################################################

ifneq ("$(TARGET_OS_FLAVOUR)","")
  -include $(BUILD_SYSTEM)/targets/$(TARGET_OS)/$(TARGET_OS_FLAVOUR)/packages.mk
endif
