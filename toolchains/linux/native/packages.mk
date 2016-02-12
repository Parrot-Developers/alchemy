###############################################################################
## @file linux/native/packages.mk
## @author Y.M. Morgan
## @date 2012/10/18
##
## This file contains package definition specific to native linux.
###############################################################################

LOCAL_PATH := $(call my-dir)

###############################################################################
# In native mode, use some module from the host machine.
###############################################################################

ifeq ("$(TARGET_OS_FLAVOUR)","native")

include $(CLEAR_VARS)
LOCAL_MODULE := libusb
LOCAL_EXPORT_LDLIBS := -lusb
$(call local-register-prebuilt-overridable)

include $(CLEAR_VARS)
LOCAL_MODULE := libusb_1_0
LOCAL_EXPORT_LDLIBS := -lusb-1.0
$(call local-register-prebuilt-overridable)

include $(CLEAR_VARS)
LOCAL_MODULE := alsa-lib
LOCAL_EXPORT_LDLIBS := -lasound
$(call local-register-prebuilt-overridable)

include $(CLEAR_VARS)
LOCAL_MODULE := libudev
LOCAL_EXPORT_LDLIBS := -ludev
$(call local-register-prebuilt-overridable)

include $(CLEAR_VARS)
LOCAL_MODULE := zlib
LOCAL_EXPORT_LDLIBS := -lz
$(call local-register-prebuilt-overridable)

ifeq ("$(TARGET_ARCH)","$(HOST_ARCH)")

ifeq ("$(shell pkg-config --exists avahi-client; echo $$?)","0")
include $(CLEAR_VARS)
LOCAL_MODULE := avahi
LOCAL_EXPORT_LDLIBS := $(shell pkg-config --libs avahi-client)
$(call local-register-prebuilt-overridable)
endif

ifeq ("$(shell pkg-config --exists json; echo $$?)","0")
include $(CLEAR_VARS)
LOCAL_MODULE := json
LOCAL_EXPORT_CFLAGS := $(shell pkg-config --cflags json)
LOCAL_EXPORT_LDLIBS := $(shell pkg-config --libs json)
$(call local-register-prebuilt-overridable)
endif

ifeq ("$(shell pkg-config --exists glib-2.0 gobject-2.0 gio-2.0; echo $$?)","0")
include $(CLEAR_VARS)
LOCAL_MODULE := glib
LOCAL_EXPORT_CFLAGS := $(shell pkg-config --cflags glib-2.0 gobject-2.0 gio-2.0)
LOCAL_EXPORT_LDLIBS := $(shell pkg-config --libs glib-2.0 gobject-2.0 gio-2.0)
$(call local-register-prebuilt-overridable)
endif

ifeq ("$(shell pkg-config --exists glesv2; echo $$?)","0")
include $(CLEAR_VARS)
LOCAL_MODULE := opengles
LOCAL_EXPORT_CFLAGS := $(shell pkg-config --cflags glesv2)
LOCAL_EXPORT_LDLIBS := $(shell pkg-config --libs glesv2)
$(call local-register-prebuilt-overridable)
endif

ifeq ("$(shell pkg-config --exists gl; echo $$?)","0")
include $(CLEAR_VARS)
LOCAL_MODULE := opengl
LOCAL_EXPORT_CFLAGS := $(shell pkg-config --cflags gl)
LOCAL_EXPORT_LDLIBS := $(shell pkg-config --libs gl)
$(call local-register-prebuilt-overridable)
endif

include $(CLEAR_VARS)
LOCAL_MODULE := libjpeg-turbo
LOCAL_EXPORT_LDLIBS := -ljpeg
$(call local-register-prebuilt-overridable)

include $(CLEAR_VARS)
LOCAL_MODULE := libtiff
LOCAL_EXPORT_LDLIBS := -ltiff
$(call local-register-prebuilt-overridable)

ifeq ("$(shell pkg-config --exists libpng; echo $$?)","0")
include $(CLEAR_VARS)
LOCAL_MODULE := libpng
LOCAL_EXPORT_CFLAGS := $(shell pkg-config --cflags libpng)
LOCAL_EXPORT_LDLIBS := $(shell pkg-config --libs libpng)
$(call local-register-prebuilt-overridable)
endif

include $(CLEAR_VARS)
LOCAL_MODULE := opencv
LOCAL_EXPORT_LDLIBS := -lopencv_flann -lopencv_core -lopencv_imgproc    \
	-lopencv_calib3d -lopencv_contrib -lopencv_features2d -lopencv_gpu  \
	-lopencv_highgui -lopencv_legacy -lopencv_ml -lopencv_objdetect     \
	-lopencv_ocl -lopencv_photo -lopencv_stitching -lopencv_superres 	\
	-lopencv_ts -lopencv_video -lopencv_videostab
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
LOCAL_LIBRARIES := libboost-system libboost-atomic libboost-chrono \
	libboost-date-time
LOCAL_EXPORT_LDLIBS := -lboost_system -lboost_atomic -lboost_chrono \
	-lboost_date_time -lboost_thread
$(call local-register-prebuilt-overridable)

include $(CLEAR_VARS)
LOCAL_MODULE := libboost
LOCAL_LIBRARIES := libboost-system libboost-thread
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
LOCAL_LIBRARIES := libblas
$(call local-register-prebuilt-overridable)

ifeq ("$(shell pkg-config --exists ncurses; echo $$?)","0")
include $(CLEAR_VARS)
LOCAL_MODULE := ncurses
LOCAL_EXPORT_CFLAGS := $(shell pkg-config --cflags ncurses)
LOCAL_EXPORT_LDLIBS := $(shell pkg-config --libs ncurses)
$(call local-register-prebuilt-overridable)
endif

ifeq ("$(shell pkg-config --exists flann; echo $$?)","0")
include $(CLEAR_VARS)
LOCAL_MODULE := flann
LOCAL_EXPORT_CFLAGS := $(shell pkg-config --cflags flann)
LOCAL_EXPORT_LDLIBS := $(shell pkg-config --libs flann)
$(call local-register-prebuilt-overridable)
endif

ifeq ("$(shell pkg-config --exists glew; echo $$?)","0")
include $(CLEAR_VARS)
LOCAL_MODULE := glew
LOCAL_EXPORT_CFLAGS := $(shell pkg-config --cflags glew)
LOCAL_EXPORT_LDLIBS := $(shell pkg-config --libs glew)
$(call local-register-prebuilt-overridable)
endif

ifeq ("$(shell pkg-config --exists glu; echo $$?)","0")
include $(CLEAR_VARS)
LOCAL_MODULE := glu
LOCAL_EXPORT_CFLAGS := $(shell pkg-config --cflags glu)
LOCAL_EXPORT_LDLIBS := $(shell pkg-config --libs glu)
$(call local-register-prebuilt-overridable)
endif

include $(CLEAR_VARS)
LOCAL_MODULE := glm
$(call local-register-prebuilt-overridable)

ifeq ("$(shell pkg-config --exists sdl; echo $$?)","0")
include $(CLEAR_VARS)
LOCAL_MODULE := sdl
LOCAL_EXPORT_CFLAGS := $(shell pkg-config --cflags sdl)
LOCAL_EXPORT_LDLIBS := $(shell pkg-config --libs sdl)
$(call local-register-prebuilt-overridable)
endif

ifeq ("$(shell pkg-config --exists SDL_image; echo $$?)","0")
include $(CLEAR_VARS)
LOCAL_MODULE := sdl-image
LOCAL_EXPORT_CFLAGS := $(shell pkg-config --cflags SDL_image)
LOCAL_EXPORT_LDLIBS := $(shell pkg-config --libs SDL_image)
$(call local-register-prebuilt-overridable)
endif

ifeq ("$(shell pkg-config --exists freetype2; echo $$?)","0")
include $(CLEAR_VARS)
LOCAL_MODULE := freetype
LOCAL_EXPORT_CFLAGS := $(shell pkg-config --cflags freetype2)
LOCAL_EXPORT_LDLIBS := $(shell pkg-config --libs freetype2)
$(call local-register-prebuilt-overridable)
endif

ifeq ("$(shell pkg-config --exists libcrypto; echo $$?)","0")
include $(CLEAR_VARS)
LOCAL_MODULE := libcrypto
LOCAL_EXPORT_LDLIBS := $(shell pkg-config --libs libcrypto)
$(call local-register-prebuilt-overridable)
endif

endif
endif
