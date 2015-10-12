###############################################################################
## @file qmake.mk
## @author Y.M. Morgan
## @date 2014/01/08
##
## Handle modules using qmake.
###############################################################################

# Set also LOCAL_MODULE so that everything works correctly
ifneq ("$(LOCAL_HOST_MODULE)","")
  LOCAL_MODULE := $(LOCAL_HOST_MODULE)
endif

LOCAL_MODULE_CLASS := QMAKE

ifeq ("$(LOCAL_QMAKE_PRO_FILE)","")
  LOCAL_QMAKE_PRO_FILE := $(LOCAL_MODULE).pro
endif

LOCAL_MODULE_FILENAME := $(LOCAL_MODULE).done
LOCAL_DONE_FILES += $(LOCAL_MODULE).done

$(module-add)
