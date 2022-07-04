###############################################################################
## @file targets/native-packages.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Additional generic packages for native target.
###############################################################################

LOCAL_PATH := $(call my-dir)

ifeq ("$(TARGET_ARCH)","$(HOST_ARCH)")

$(call register-prebuilt-pkg-config-module,expat,expat)
$(call register-prebuilt-pkg-config-module,freetype,freetype2)
$(call register-prebuilt-pkg-config-module,glew,glew)
$(call register-prebuilt-pkg-config-module,glfw3,glfw3)
$(call register-prebuilt-pkg-config-module,json,json-c)
$(call register-prebuilt-pkg-config-module,libcunit,libcunit)
$(call register-prebuilt-pkg-config-module,libffi,libffi)
$(call register-prebuilt-pkg-config-module,liblz4,liblz4)
$(call register-prebuilt-pkg-config-module,libusb,libusb)
$(call register-prebuilt-pkg-config-module,libusb_1_0,libusb-1.0)
$(call register-prebuilt-pkg-config-module,libxml2,libxml-2.0)
$(call register-prebuilt-pkg-config-module,ncurses,ncurses)
$(call register-prebuilt-pkg-config-module,sdl2,sdl2)
$(call register-prebuilt-pkg-config-module,zlib,zlib)

$(call register-prebuilt-pkg-config-module,glib-2.0,glib-2.0)
$(call register-prebuilt-pkg-config-module,gobject-2.0,gobject-2.0)
$(call register-prebuilt-pkg-config-module,gio-2.0,gio-2.0)
$(call register-prebuilt-pkg-config-module,x11,x11)

include $(CLEAR_VARS)
LOCAL_MODULE := qt5-base
$(call local-register-prebuilt-overridable)

_glib_deps := glib-2.0 gobject-2.0 gio-2.0
_glib_deps_available := $(call is-module-list-registered,$(_glib_deps))
ifneq ("$(_glib_deps_available)","")
include $(CLEAR_VARS)
LOCAL_MODULE := glib
LOCAL_LIBRARIES := $(_glib_deps)
$(call local-register-prebuilt-overridable)
endif

$(call register-prebuilt-pkg-config-module,gstreamer-1.0,gstreamer-1.0)
$(call register-prebuilt-pkg-config-module,gstreamer-app-1.0,gstreamer-app-1.0)
$(call register-prebuilt-pkg-config-module,gstreamer-audio-1.0,gstreamer-audio-1.0)
$(call register-prebuilt-pkg-config-module,gstreamer-base-1.0,gstreamer-base-1.0)
$(call register-prebuilt-pkg-config-module,gstreamer-video-1.0,gstreamer-video-1.0)

_gstreamer_deps := gstreamer-1.0 gstreamer-base-1.0
_gstreamer_deps_available := $(call is-module-list-registered,$(_gstreamer_deps))
ifneq ("$(_gstreamer_deps_available)","")
include $(CLEAR_VARS)
LOCAL_MODULE := gstreamer
LOCAL_LIBRARIES := $(_gstreamer_deps)
$(call local-register-prebuilt-overridable)
endif

_gst-plugins-base_deps := gstreamer-app-1.0 gstreamer-audio-1.0 gstreamer-video-1.0
_gst-plugins-base_deps_available := $(call is-module-list-registered,$(_gst-plugins-base_deps))
ifneq ("$(_gst-plugins-base_deps_available)","")
include $(CLEAR_VARS)
LOCAL_MODULE := gst-plugins-base
LOCAL_LIBRARIES := $(_gst-plugins-base_deps)
$(call local-register-prebuilt-overridable)
endif

endif

# If ncurses not available via pkg-config, try harder...
ifeq ("$(call is-module-registered,ncurses)","")
  ifneq ("$(wildcard /usr/include/ncurses.h)","")
    include $(CLEAR_VARS)
    LOCAL_MODULE := ncurses
    LOCAL_EXPORT_LDLIBS := -lncurses
    $(call local-register-prebuilt-overridable)
  endif
endif
