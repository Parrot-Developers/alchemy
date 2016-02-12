###############################################################################
## @file shared.mk
## @author Y.M. Morgan
## @date 2011/05/14
##
## Build a shared library.
###############################################################################

# Set also LOCAL_MODULE so that everything works correctly
ifneq ("$(LOCAL_HOST_MODULE)","")
  LOCAL_MODULE := $(LOCAL_HOST_MODULE)
endif

# check if we want to force static libraries
force_static := 0
ifeq ("$(TARGET_FORCE_STATIC)","1")
  force_static := 1
else ifeq ("$(TARGET_PBUILD_FORCE_STATIC)","1")
  ifeq ("$(LOCAL_PBUILD_ALLOW_FORCE_STATIC)","1")
    force_static := 1
  endif
endif

ifeq ("$(force_static)","1")
LOCAL_MODULE_CLASS := STATIC_LIBRARY
LOCAL_EXPORT_LDLIBS += $(LOCAL_LDLIBS)
suffix := $(TARGET_STATIC_LIB_SUFFIX)
else
LOCAL_MODULE_CLASS := SHARED_LIBRARY
suffix := $(TARGET_SHARED_LIB_SUFFIX)
endif

ifeq ("$(LOCAL_DESTDIR)","")
  LOCAL_DESTDIR := $(TARGET_DEFAULT_LIB_DESTDIR)
endif

ifeq ("$(LOCAL_MODULE_FILENAME)","")
  ifeq ("$(USE_AUTO_LIB_PREFIX)","1")
    LOCAL_MODULE_FILENAME := lib$(LOCAL_MODULE:lib%=%)$(suffix)
  else
    LOCAL_MODULE_FILENAME := $(LOCAL_MODULE)$(suffix)
  endif
else ifeq ("$(force_static)","1")
  LOCAL_MODULE_FILENAME := $(LOCAL_MODULE_FILENAME:.so=$(TARGET_STATIC_LIB_SUFFIX))
  LOCAL_MODULE_FILENAME := $(LOCAL_MODULE_FILENAME:$(TARGET_SHARED_LIB_SUFFIX)=$(TARGET_STATIC_LIB_SUFFIX))
else
  # In case the module specified a .so extension, put the correct one
  LOCAL_MODULE_FILENAME := $(LOCAL_MODULE_FILENAME:.so=$(TARGET_SHARED_LIB_SUFFIX))
endif

$(module-add)
