###############################################################################
## @file classes/SHARED_LIBRARY/register.mk
## @author Y.M. Morgan
## @date 2011/05/14
##
## Register SHARED_LIBRARY modules.
###############################################################################

ifneq ("$(LOCAL_HOST_MODULE)","")
  $(error $(LOCAL_PATH): SHARED_LIBRARY not supported for host modules)
endif

# check if we want to force static libraries
force_static := 0
ifneq ("$(LOCAL_HOST_MODULE)","")
  force_static := 1
else ifeq ("$(TARGET_FORCE_STATIC)","1")
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
  ifeq ("$(TARGET_OS)","windows")
    ifeq ("$(force_static)","1")
      LOCAL_DESTDIR := $(TARGET_DEFAULT_LIB_DESTDIR)
    else
      LOCAL_DESTDIR := $(TARGET_DEFAULT_BIN_DESTDIR)
    endif
  else
    LOCAL_DESTDIR := $(TARGET_DEFAULT_LIB_DESTDIR)
  endif
else ifneq ("$(TARGET_ROOT_DESTDIR)","usr")
  LOCAL_DESTDIR := $(patsubst usr/%,$(TARGET_ROOT_DESTDIR)/%,$(LOCAL_DESTDIR))
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

# Register in the system
$(module-add)
