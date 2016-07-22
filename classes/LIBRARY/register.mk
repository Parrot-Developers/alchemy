###############################################################################
## @file classes/LIBRARY/register.mk
## @author Y.M. Morgan
## @date 2014/08/09
##
## Register LIBRARY modules.
###############################################################################

# Set also LOCAL_MODULE so that everything works correctly
ifneq ("$(LOCAL_HOST_MODULE)","")
  LOCAL_MODULE := $(LOCAL_HOST_MODULE)
  _mode_prefix := HOST
else
  _mode_prefix := TARGET
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

# Unless static is forced, use shared suffix and 'LIBRARY' class
# Build system will automatically adjust suffix when required
ifeq ("$(force_static)","1")
  LOCAL_MODULE_CLASS := STATIC_LIBRARY
  LOCAL_EXPORT_LDLIBS += $(LOCAL_LDLIBS)
  suffix := $($(_mode_prefix)_STATIC_LIB_SUFFIX)
else
  LOCAL_MODULE_CLASS := LIBRARY
  # Only target mode supported for mixed shared/static
  suffix := $(TARGET_SHARED_LIB_SUFFIX)
endif

ifeq ("$(LOCAL_DESTDIR)","")
  ifeq ("$($(_mode_prefix)_OS)","windows")
    ifeq ("$(force_static)","1")
      LOCAL_DESTDIR := $($(_mode_prefix)_DEFAULT_LIB_DESTDIR)
    else
      LOCAL_DESTDIR := $($(_mode_prefix)_DEFAULT_BIN_DESTDIR)
    endif
  else
    LOCAL_DESTDIR := $($(_mode_prefix)_DEFAULT_LIB_DESTDIR)
  endif
else ifneq ("$($(_mode_prefix)_ROOT_DESTDIR)","usr")
  LOCAL_DESTDIR := $(patsubst usr/%,$($(_mode_prefix)_ROOT_DESTDIR)/%,$(LOCAL_DESTDIR))
endif

ifeq ("$(LOCAL_MODULE_FILENAME)","")
  ifeq ("$(USE_AUTO_LIB_PREFIX)","1")
    LOCAL_MODULE_FILENAME := lib$(LOCAL_MODULE:lib%=%)$(suffix)
  else
    LOCAL_MODULE_FILENAME := $(LOCAL_MODULE)$(suffix)
  endif
else ifeq ("$(force_static)","1")
  # In case the module specified a .so extension, put the correct one
  LOCAL_MODULE_FILENAME := $(LOCAL_MODULE_FILENAME:.so=$($(_mode_prefix)_STATIC_LIB_SUFFIX))
  LOCAL_MODULE_FILENAME := $(LOCAL_MODULE_FILENAME:$($(_mode_prefix)_SHARED_LIB_SUFFIX)=$($(_mode_prefix)_STATIC_LIB_SUFFIX))
else
  # In case the module specified a .so extension, put the correct one
  LOCAL_MODULE_FILENAME := $(LOCAL_MODULE_FILENAME:.so=$($(_mode_prefix)_SHARED_LIB_SUFFIX))
endif

# Register in the system
$(module-add)
