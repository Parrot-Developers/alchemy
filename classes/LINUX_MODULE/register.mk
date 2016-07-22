###############################################################################
## @file classes/LINUX_MODULE/register.mk
## @author R. Lefèvre
## @date 2014/09/11
##
## Register LINUX_MODULE modules.
###############################################################################

ifneq ("$(LOCAL_HOST_MODULE)","")
  $(error $(LOCAL_PATH): LINUX_MODULE not supported for host modules)
endif

ifeq ("$(LOCAL_MODULE_FILENAME)","")
  LOCAL_MODULE_FILENAME := $(LOCAL_MODULE).ko
endif

LOCAL_MODULE_CLASS := LINUX_MODULE

ifneq ("$(TARGET_OS_FLAVOUR:-chroot=)","native")
  LOCAL_LIBRARIES += linux
endif

# Register in the system
$(module-add)
