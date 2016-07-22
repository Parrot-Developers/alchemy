###############################################################################
## @file classes/GI_TYPELIB/rules.mk
## @author Y.M. Morgan
## @date 2016/03/20
##
## Rules for GI_TYPELIB modules.
###############################################################################

# Prepend some directories in include list
LOCAL_C_INCLUDES := $(build_dir) $(LOCAL_PATH) $(LOCAL_C_INCLUDES)

# List of sources

c_sources := $(addprefix $(LOCAL_PATH)/,$(filter %.c,$(LOCAL_SRC_FILES)))
c_headers := $(addprefix $(LOCAL_PATH)/,$(filter %.h,$(LOCAL_SRC_FILES)))

all_sources := $(c_headers) $(c_sources)

_module_msg := $(if $(_mode_host),Host )GiTypeLib

include $(BUILD_SYSTEM)/classes/GENERIC/rules.mk

# Gir file
$(LOCAL_BUILD_MODULE:.typelib=.gir): $(all_link_libs_filenames) $(all_sources)
	$(transform-c-to-gir)

# Typelib library
$(LOCAL_BUILD_MODULE): $(LOCAL_BUILD_MODULE:.typelib=.gir)
	$(transform-gir-to-typelib)

# Copy to staging/final directory
LOCAL_FINAL_MODULE := $(LOCAL_STAGING_MODULE:$(TARGET_OUT_STAGING)/%=$(TARGET_OUT_FINAL)/%)
$(call _binary-copy-to-staging,$(_mode_prefix),$(LOCAL_BUILD_MODULE),$(LOCAL_STAGING_MODULE))
$(call _binary-copy-to-final,$(_mode_prefix),$(LOCAL_STAGING_MODULE),$(LOCAL_FINAL_MODULE))

$(LOCAL_TARGETS): PRIVATE_GI_NAMESPACE := $(LOCAL_GI_NAMESPACE)
$(LOCAL_TARGETS): PRIVATE_GI_LIBRARY := $(LOCAL_GI_LIBRARY)
$(LOCAL_TARGETS): PRIVATE_GI_ID_PREFIX := $(LOCAL_GI_ID_PREFIX)
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(_module_build_dir)/$(LOCAL_MODULE_FILENAME:.typelib=.gir)
$(LOCAL_TARGETS): PRIVATE_OBJ_DIR := $(_module_build_dir)/obj
$(LOCAL_TARGETS): PRIVATE_CFLAGS := $(LOCAL_CFLAGS)
$(LOCAL_TARGETS): PRIVATE_LDFLAGS := $(LOCAL_LDFLAGS)
$(LOCAL_TARGETS): PRIVATE_LDLIBS := $(LOCAL_LDLIBS)
$(LOCAL_TARGETS): PRIVATE_C_INCLUDES := $(LOCAL_C_INCLUDES)
$(LOCAL_TARGETS): PRIVATE_ALL_SOURCES := $(all_sources)
