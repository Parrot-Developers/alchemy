###############################################################################
## @file classes/PREBUILT/rules.mk
## @author Y.M. Morgan
## @date 2016/03/20
##
## Rules for PREBUILT modules.
###############################################################################

_module_msg := $(if $(_mode_host),Host )Prebuilt

include $(BUILD_SYSTEM)/classes/GENERIC/rules.mk

# Simply 'touch' the 'done' file
# Not done by GENERIC because PREBUILT is an internal module)
$(LOCAL_BUILD_MODULE):
	@mkdir -p $(dir $@)
	@touch $@
