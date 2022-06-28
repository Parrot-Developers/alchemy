###############################################################################
## @file targets/linux/native/packages.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Additional packages for linux/native target.
###############################################################################

LOCAL_PATH := $(call my-dir)

# Declare linux module if we have headers
ifneq ("$(wildcard /lib/modules/$(TARGET_LINUX_RELEASE)/build)","")
  include $(CLEAR_VARS)
  LOCAL_MODULE := linux
  $(call local-register-prebuilt-overridable)
endif

$(call register-prebuilt-pkg-config-module,alsa-lib,alsa)
$(call register-prebuilt-pkg-config-module,libudev,libudev)


ifeq ("$(TARGET_ARCH)","$(HOST_ARCH)")

$(call register-prebuilt-pkg-config-module,avahi-client,avahi-client)
$(call register-prebuilt-pkg-config-module,opengles,glesv2)
$(call register-prebuilt-pkg-config-module,opengl,gl)
$(call register-prebuilt-pkg-config-module,libpng,libpng)
$(call register-prebuilt-pkg-config-module,flann,flann)
$(call register-prebuilt-pkg-config-module,glu,glu)
$(call register-prebuilt-pkg-config-module,sdl,sdl)
$(call register-prebuilt-pkg-config-module,sdl-image,SDL_image)
$(call register-prebuilt-pkg-config-module,libcrypto,libcrypto libssl)
$(call register-prebuilt-pkg-config-module,egl,egl)
ifeq ("$(shell pkg-config --exists opencv4; echo $$?)","1")
$(call register-prebuilt-pkg-config-module,opencv,opencv)
else
$(call register-prebuilt-pkg-config-module,opencv,opencv4)
endif
$(call register-prebuilt-pkg-config-module,libav-ffmpeg,libavcodec \
	libavresample libavutil libavformat)

# merge libjpeg and libturbo-jpeg into the libjpeg-turbo name
$(call register-prebuilt-pkg-config-module,libjpeg-turbo,libjpeg libturbojpeg)

include $(CLEAR_VARS)
LOCAL_MODULE := libtiff
LOCAL_EXPORT_LDLIBS := -ltiff
$(call local-register-prebuilt-overridable)

include $(CLEAR_VARS)
LOCAL_MODULE := libboost-system
LOCAL_EXPORT_LDLIBS := -lboost_system
$(call local-register-prebuilt-overridable)

include $(CLEAR_VARS)
LOCAL_MODULE := libboost-atomic
LOCAL_EXPORT_LDLIBS := -lboost_atomic
$(call local-register-prebuilt-overridable)

include $(CLEAR_VARS)
LOCAL_MODULE := libboost-chrono
LOCAL_EXPORT_LDLIBS := -lboost_chrono
$(call local-register-prebuilt-overridable)

include $(CLEAR_VARS)
LOCAL_MODULE := libboost-date-time
LOCAL_EXPORT_LDLIBS := -lboost_date_time
$(call local-register-prebuilt-overridable)

include $(CLEAR_VARS)
LOCAL_MODULE := libboost-regex
LOCAL_EXPORT_LDLIBS := -lboost_regex
$(call local-register-prebuilt-overridable)

include $(CLEAR_VARS)
LOCAL_MODULE := libboost-filesystem
LOCAL_EXPORT_LDLIBS := -lboost_filesystem
$(call local-register-prebuilt-overridable)

include $(CLEAR_VARS)
LOCAL_MODULE := libboost-thread
LOCAL_EXPORT_LDLIBS := -lboost_system -lboost_atomic -lboost_chrono \
	-lboost_date_time -lboost_thread
$(call local-register-prebuilt-overridable)

include $(CLEAR_VARS)
LOCAL_MODULE := libboost
LOCAL_EXPORT_LDLIBS := -lboost_system -lboost_atomic -lboost_chrono \
	-lboost_date_time -lboost_thread -lboost_regex -lboost_filesystem
$(call local-register-prebuilt-overridable)

include $(CLEAR_VARS)
LOCAL_MODULE := libblas
LOCAL_EXPORT_LDLIBS := -lblas
$(call local-register-prebuilt-overridable)

include $(CLEAR_VARS)
LOCAL_MODULE := liblapack
LOCAL_EXPORT_LDLIBS := -llapack
$(call local-register-prebuilt-overridable)

include $(CLEAR_VARS)
LOCAL_MODULE := libav
LOCAL_EXPORT_LDLIBS := -lavformat -lavcodec -lavutil
$(call local-register-prebuilt-overridable)

include $(CLEAR_VARS)
LOCAL_MODULE := glm
$(call local-register-prebuilt-overridable)

ifeq ("$(shell pkg-config --exists bluez; echo $$?)","0")
include $(CLEAR_VARS)
LOCAL_MODULE := bluez
LOCAL_EXPORT_LDLIBS := $(shell pkg-config --libs bluez)
LOCAL_EXPORT_CFLAGS := \
	-D__BLUEZ__=$(shell pkg-config --modversion bluez | cut -f1 -d'.') \
	-D__BLUEZ_MINOR__=$(shell pkg-config --modversion bluez | cut -f2 -d'.')
$(call local-register-prebuilt-overridable)
endif

endif
