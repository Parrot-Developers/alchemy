###############################################################################
## @file targets/windows/packages.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Additional packages for windows target.
###############################################################################

LOCAL_PATH := $(call my-dir)

ifneq ("$(TARGET_ARCH)","$(HOST_ARCH)")

$(call register-prebuilt-pkg-config-module-with-path,json,json-c,$(TARGET_PKG_CONFIG_PATH))
$(call register-prebuilt-pkg-config-module-with-path,libarchive,libarchive,$(TARGET_PKG_CONFIG_PATH))
$(call register-prebuilt-pkg-config-module-with-path,liblz4,liblz4,$(TARGET_PKG_CONFIG_PATH))
$(call register-prebuilt-pkg-config-module-with-path,libraw,libraw,$(TARGET_PKG_CONFIG_PATH))
$(call register-prebuilt-pkg-config-module-with-path,libxml2,libxml-2.0,$(TARGET_PKG_CONFIG_PATH))
$(call register-prebuilt-pkg-config-module-with-path,sdl2,sdl2,$(TARGET_PKG_CONFIG_PATH))
$(call register-prebuilt-pkg-config-module-with-path,zlib,zlib,$(TARGET_PKG_CONFIG_PATH))

# GStreamer
$(call register-prebuilt-pkg-config-module-with-path,gstreamer-1.0,gstreamer-1.0,$(TARGET_PKG_CONFIG_PATH))
$(call register-prebuilt-pkg-config-module-with-path,gstreamer-app-1.0,gstreamer-app-1.0,$(TARGET_PKG_CONFIG_PATH))
$(call register-prebuilt-pkg-config-module-with-path,gstreamer-audio-1.0,gstreamer-audio-1.0,$(TARGET_PKG_CONFIG_PATH))
$(call register-prebuilt-pkg-config-module-with-path,gstreamer-base-1.0,gstreamer-base-1.0,$(TARGET_PKG_CONFIG_PATH))
$(call register-prebuilt-pkg-config-module-with-path,gstreamer-video-1.0,gstreamer-video-1.0,$(TARGET_PKG_CONFIG_PATH))

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
