###############################################################################
## @file classes/STATIC_LIBRARY/rules.mk
## @author Y.M. Morgan
## @date 2016/03/20
##
## Rules for STATIC_LIBRARY modules.
###############################################################################

ifneq ("$(LOCAL_SDK)","")

include $(BUILD_SYSTEM)/classes/GENERIC/rules.mk

$(LOCAL_BUILD_MODULE):
	@mkdir -p $(dir $@)
	@touch $@

else

_module_msg := $(if $(_mode_host),Host )StaticLib

include $(BUILD_SYSTEM)/classes/BINARY/rules.mk

$(LOCAL_BUILD_MODULE): $(all_objects)
	$(transform-o-to-static-lib)

# Copy to staging directory only
$(call _binary-copy-to-staging,$(_mode_prefix),$(LOCAL_BUILD_MODULE),$(LOCAL_STAGING_MODULE))

endif
