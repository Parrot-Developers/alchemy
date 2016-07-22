###############################################################################
## @file classes/EXECUTABLE/register.mk
## @author Y.M. Morgan
## @date 2011/05/14
##
## Register EXECUTABLE modules.
###############################################################################

# Set also LOCAL_MODULE so that everything works correctly
ifneq ("$(LOCAL_HOST_MODULE)","")
  LOCAL_MODULE := $(LOCAL_HOST_MODULE)
  _mode_prefix := HOST
else
  _mode_prefix := TARGET
endif

LOCAL_MODULE_CLASS := EXECUTABLE

ifeq ("$(LOCAL_DESTDIR)","")
  LOCAL_DESTDIR := $($(_mode_prefix)_DEFAULT_BIN_DESTDIR)
else ifneq ("$($(_mode_prefix)_ROOT_DESTDIR)","usr")
  LOCAL_DESTDIR := $(patsubst usr/%,$($(_mode_prefix)_ROOT_DESTDIR)/%,$(LOCAL_DESTDIR))
endif

ifeq ("$(LOCAL_MODULE_FILENAME)","")
  LOCAL_MODULE_FILENAME := $(LOCAL_MODULE)$($(_mode_prefix)_EXE_SUFFIX)
endif

# On toolchain arm-2012.03 for static binaries
# force link with libc-arm-2012-03-fix.a to override libc symbols
ifneq ("$(call str-starts-with,$(TARGET_CC_PATH),/opt/arm-2012.03)","")
ifneq ("$(findstring -static,$(LOCAL_LDFLAGS))","")
  LOCAL_STATIC_LIBRARIES += libc-arm-2012-03-fix
endif
endif

# Register in the system
$(module-add)
