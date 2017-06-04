###############################################################################
## @file classes/CUSTOM/rules.mk
## @author Y.M. Morgan
## @date 2016/03/20
##
## Rules for CUSTOM modules.
###############################################################################

# Nothing to do
_module_msg := $(if $(_mode_host),Host )Custom

include $(BUILD_SYSTEM)/classes/GENERIC/rules.mk

$(LOCAL_TARGETS): PRIVATE_ALL_LIBS := $(all_libs)
