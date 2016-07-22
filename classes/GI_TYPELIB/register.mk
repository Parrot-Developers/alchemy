###############################################################################
## @file classes/GI_TYPELIB/register.mk
## @author R. Lefèvre
## @date 2015/05/11
##
## Register GI_TYPELIB modules.
###############################################################################

ifneq ("$(LOCAL_HOST_MODULE)","")
  $(error $(LOCAL_PATH): GI_TYPELIB not supported for host modules)
endif

LOCAL_MODULE_CLASS := GI_TYPELIB

ifeq ("$(LOCAL_GI_ID_PREFIX)","")
  LOCAL_GI_ID_PREFIX := $(LOCAL_GI_NAMESPACE)
endif

ifeq ("$(LOCAL_MODULE_FILENAME)","")
  LOCAL_MODULE_FILENAME := $(LOCAL_GI_NAMESPACE)-1.0.typelib
endif

LOCAL_DEPENDS_HOST_MODULES += host.gobject-introspection
LOCAL_LIBRARIES += $(LOCAL_GI_LIBRARY)

ifeq ("$(LOCAL_DESTDIR)","")
  LOCAL_DESTDIR := $(TARGET_DEFAULT_LIB_DESTDIR)/girepository-1.0
else ifneq ("$(TARGET_ROOT_DESTDIR)","usr")
  LOCAL_DESTDIR := $(patsubst usr/%,$(TARGET_ROOT_DESTDIR)/%,$(LOCAL_DESTDIR))
endif

# Register in the system
$(module-add)
