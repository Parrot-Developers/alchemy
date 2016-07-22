###############################################################################
## @file classes/EXECUTABLE/rules.mk
## @author Y.M. Morgan
## @date 2016/03/20
##
## Rules for EXECUTABLE modules.
###############################################################################

_module_msg := $(if $(_mode_host),Host )Executable

include $(BUILD_SYSTEM)/classes/BINARY/rules.mk

ifneq ("$(LOCAL_LDSCRIPT)","")
$(LOCAL_BUILD_MODULE): $(LOCAL_PATH)/$(LOCAL_LDSCRIPT)
$(LOCAL_TARGETS): PRIVATE_LDFLAGS += -T $(LOCAL_PATH)/$(LOCAL_LDSCRIPT)
endif

$(LOCAL_BUILD_MODULE): $(all_objects) $(all_link_libs_filenames)
	$(transform-o-to-executable)
ifneq ("$(TARGET_ADD_DEPENDS_SECTION)","0")
	$(add-depends-section)
endif

# Copy to staging/final directory
LOCAL_FINAL_MODULE := $(LOCAL_STAGING_MODULE:$(TARGET_OUT_STAGING)/%=$(TARGET_OUT_FINAL)/%)
$(call _binary-copy-to-staging,$(_mode_prefix),$(LOCAL_BUILD_MODULE),$(LOCAL_STAGING_MODULE))
$(call _binary-copy-to-final,$(_mode_prefix),$(LOCAL_STAGING_MODULE),$(LOCAL_FINAL_MODULE))
