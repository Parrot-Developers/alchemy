###############################################################################
## @file classes/QMAKE/register.mk
## @author Y.M. Morgan
## @date 2014/01/08
##
## Register QMAKE modules.
###############################################################################

ifneq ("$(LOCAL_HOST_MODULE)","")
  $(error $(LOCAL_PATH): QMAKE not supported for host modules)
endif

LOCAL_MODULE_CLASS := QMAKE

ifeq ("$(LOCAL_QMAKE_PRO_FILE)","")
  LOCAL_QMAKE_PRO_FILE := $(LOCAL_MODULE).pro
endif

LOCAL_MODULE_FILENAME := $(LOCAL_MODULE).done
LOCAL_DONE_FILES += $(LOCAL_MODULE).done

# Register in the system
$(module-add)
