###############################################################################
## @file classes/STATIC_LIBRARY/register.mk
## @author Y.M. Morgan
## @date 2011/05/14
##
## Register STATIC_LIBRARY modules.
###############################################################################

# Set also LOCAL_MODULE so that everything works correctly
ifneq ("$(LOCAL_HOST_MODULE)","")
  LOCAL_MODULE := $(LOCAL_HOST_MODULE)
  _mode_prefix := HOST
else
  _mode_prefix := TARGET
endif

LOCAL_MODULE_CLASS := STATIC_LIBRARY

ifeq ("$(LOCAL_DESTDIR)","")
  LOCAL_DESTDIR := $($(_mode_prefix)_DEFAULT_LIB_DESTDIR)
else ifneq ("$($(_mode_prefix)_ROOT_DESTDIR)","usr")
  LOCAL_DESTDIR := $(patsubst usr/%,$($(_mode_prefix)_ROOT_DESTDIR)/%,$(LOCAL_DESTDIR))
endif

ifeq ("$(LOCAL_MODULE_FILENAME)","")
  ifeq ("$(USE_AUTO_LIB_PREFIX)","1")
    LOCAL_MODULE_FILENAME := lib$(LOCAL_MODULE:lib%=%)$($(_mode_prefix)_STATIC_LIB_SUFFIX)
  else
    LOCAL_MODULE_FILENAME := $(LOCAL_MODULE)$($(_mode_prefix)_STATIC_LIB_SUFFIX)
  endif
endif

# Register in the system
$(module-add)
