###############################################################################
## @file autotools.mk
## @author Y.M. Morgan
## @date 2012/07/13
##
## Handle modules using autotools.
###############################################################################

# Set also LOCAL_MODULE so that everything works correctly
ifneq ("$(LOCAL_HOST_MODULE)","")
  LOCAL_MODULE := $(LOCAL_HOST_MODULE)
endif

LOCAL_MODULE_CLASS := AUTOTOOLS

LOCAL_MODULE_FILENAME := $(LOCAL_MODULE).done
LOCAL_DONE_FILES += $(LOCAL_MODULE).done

# Compatiblity
LOCAL_ARCHIVE := $(LOCAL_AUTOTOOLS_ARCHIVE)
LOCAL_ARCHIVE_VERSION := $(LOCAL_AUTOTOOLS_VERSION)
LOCAL_ARCHIVE_SUBDIR := $(LOCAL_AUTOTOOLS_SUBDIR)
LOCAL_ARCHIVE_PATCHES := $(LOCAL_AUTOTOOLS_PATCHES)
LOCAL_COPY_TO_BUILD_DIR := $(LOCAL_AUTOTOOLS_COPY_TO_BUILD_DIR)
$(call macro-copy,LOCAL_ARCHIVE_CMD_UNPACK,LOCAL_AUTOTOOLS_CMD_UNPACK)
$(call macro-copy,LOCAL_ARCHIVE_CMD_POST_UNPACK,LOCAL_AUTOTOOLS_CMD_POST_UNPACK)

$(module-add)
