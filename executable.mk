###############################################################################
## @file executable.mk
## @author Y.M. Morgan
## @date 2011/05/14
##
## Build an executable.
###############################################################################

# Set also LOCAL_MODULE so that everything works correctly
ifneq ("$(LOCAL_HOST_MODULE)","")
  LOCAL_MODULE := $(LOCAL_HOST_MODULE)
endif

LOCAL_MODULE_CLASS := EXECUTABLE

ifeq ("$(LOCAL_DESTDIR)","")
LOCAL_DESTDIR := $(TARGET_DEFAULT_BIN_DESTDIR)
endif

ifeq ("$(LOCAL_MODULE_FILENAME)","")
LOCAL_MODULE_FILENAME := $(LOCAL_MODULE)$(TARGET_EXE_SUFFIX)
endif

# on toolchain arm-2012.03 for static binaries
# force link with libc-arm-2012-03-fix.a to override libc symbols
ifneq ("$(call str-starts-with,$(TARGET_CC_PATH),/opt/arm-2012.03)","")
ifneq ("$(findstring -static,$(LOCAL_LDFLAGS))","")
  LOCAL_STATIC_LIBRARIES += libc-arm-2012-03-fix
endif
endif

$(module-add)
