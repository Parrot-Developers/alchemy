###############################################################################
## @file classes/LINUX/rules.mk
## @author Y.M. Morgan
## @date 2016/03/20
##
## Rules for LINUX modules.
###############################################################################

ifeq ("$(LOCAL_MODULE)", "linux")
  include $(BUILD_SYSTEM)/classes/LINUX/rules-linux.mk
else ifeq ("$(LOCAL_MODULE)", "perf")
  include $(BUILD_SYSTEM)/classes/LINUX/rules-perf.mk
endif
