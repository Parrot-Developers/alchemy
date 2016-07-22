###############################################################################
## @file classes/PREBUILT/register.mk
## @author Y.M. Morgan
## @date 2012/08/08
##
## Register PREBUILT modules.
###############################################################################

# Set also LOCAL_MODULE so that everything works correctly
ifneq ("$(LOCAL_HOST_MODULE)","")
  LOCAL_MODULE := $(LOCAL_HOST_MODULE)
endif

LOCAL_MODULE_CLASS := PREBUILT

ifeq ("$(LOCAL_MODULE_FILENAME)","")
  LOCAL_MODULE_FILENAME := $(LOCAL_MODULE).done
endif

# Register in the system
$(module-add)
