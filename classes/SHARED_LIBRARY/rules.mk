###############################################################################
## @file classes/SHARED_LIBRARY/rules.mk
## @author Y.M. Morgan
## @date 2016/03/20
##
## Rules for SHARED_LIBRARY modules.
###############################################################################

ifneq ("$(LOCAL_SDK)","")

include $(BUILD_SYSTEM)/classes/GENERIC/rules.mk

else

_module_msg := $(if $(_mode_host),Host )SharedLib

include $(BUILD_SYSTEM)/classes/BINARY/rules.mk

$(LOCAL_BUILD_MODULE): $(all_objects) $(all_link_libs_filenames)
	$(transform-o-to-shared-lib)
ifneq ("$(TARGET_ADD_DEPENDS_SECTION)","0")
	$(add-depends-section)
endif

# Copy to staging/final directory
LOCAL_FINAL_MODULE := $(LOCAL_STAGING_MODULE:$(TARGET_OUT_STAGING)/%=$(TARGET_OUT_FINAL)/%)
$(call _binary-copy-to-staging,$(_mode_prefix),$(LOCAL_BUILD_MODULE),$(LOCAL_STAGING_MODULE))
$(call _binary-copy-to-final,$(_mode_prefix),$(LOCAL_STAGING_MODULE),$(LOCAL_FINAL_MODULE))

endif
