###############################################################################
## @file classes/AUTOTOOLS/register.mk
## @author Y.M. Morgan
## @date 2012/07/13
##
## Register AUTOTOOLS modules.
###############################################################################

# Set also LOCAL_MODULE so that everything works correctly
ifneq ("$(LOCAL_HOST_MODULE)","")
  LOCAL_MODULE := $(LOCAL_HOST_MODULE)
endif

LOCAL_MODULE_CLASS := AUTOTOOLS

LOCAL_MODULE_FILENAME := $(LOCAL_MODULE).done
LOCAL_DONE_FILES += $(LOCAL_MODULE).done

# Register in the system
$(module-add)
