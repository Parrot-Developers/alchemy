###############################################################################
## @file static.mk
## @author Y.M. Morgan
## @date 2011/05/14
##
## Build a static library.
###############################################################################

# Set also LOCAL_MODULE so that everything works correctly
ifneq ("$(LOCAL_HOST_MODULE)","")
  LOCAL_MODULE := $(LOCAL_HOST_MODULE)
endif

LOCAL_MODULE_CLASS := STATIC_LIBRARY

ifeq ("$(LOCAL_DESTDIR)","")
LOCAL_DESTDIR := $(TARGET_DEFAULT_LIB_DESTDIR)
endif

ifeq ("$(LOCAL_MODULE_FILENAME)","")
LOCAL_MODULE_FILENAME := $(LOCAL_MODULE)$(TARGET_STATIC_LIB_SUFFIX)
endif

$(module-add)
