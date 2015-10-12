###############################################################################
## @file gobject-introspection.mk
## @author R. Lefèvre
## @date 2015/05/11
##
## Build a gobject-introspection type library.
###############################################################################

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
LOCAL_DESTDIR := usr/lib/girepository-1.0
endif

# Register as a custom build in the system
$(module-add)
