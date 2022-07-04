###############################################################################
## @file targets/linux/native-chroot/packages.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Additional packages for linux/native-chroot target.
###############################################################################

LOCAL_PATH := $(call my-dir)

###############################################################################
# Module from the host are made available by creating links to include/lib
# in the host to avoid bringing too many stuff in search directories.
#
# Please note that in order to have something working at runtime it the
# libraries and the dependencies need to be made available in the chroot'ed
# environment.
###############################################################################

# $1: name of the module
# $2: include directories to create symlink
# $3: lib names to create symlink
# $4: lib name to add in -Wl option
# $5: extra dependencies
define register-native-chroot-module

include $(CLEAR_VARS)

LOCAL_MODULE := $1

define LOCAL_CMD_BUILD
	@mkdir -p $$(PRIVATE_BUILD_DIR)/include
	@mkdir -p $$(PRIVATE_BUILD_DIR)/lib
	$$(foreach d,$2, \
		$(Q) ln -sf $$d $$(PRIVATE_BUILD_DIR)/include/$$(endl) \
	)
	$$(foreach d,$3, \
		$(Q) ln -sf $$d $$(PRIVATE_BUILD_DIR)/lib/$$(endl) \
	)
endef

LOCAL_EXPORT_C_INCLUDES := $$(call local-get-build-dir)/include
LOCAL_EXPORT_LDLIBS := -Wl,--unresolved-symbols=ignore-in-shared-libs,-L$$(call local-get-build-dir)/lib,$(subst $(space),$(comma),$(strip $4))
LOCAL_LIBRARIES := $5

$$(call local-register-prebuilt-overridable)

endef

$(eval $(call register-native-chroot-module, \
	opengl, \
	/usr/include/GL /usr/include/KHR, \
	/usr/lib/$(TARGET_TOOLCHAIN_TRIPLET)/libGL.so, \
	-lGL,\
	$(empty)))

$(eval $(call register-native-chroot-module, \
	opengles,\
	/usr/include/GLES2 /usr/include/GLES3, \
	/usr/lib/$(TARGET_TOOLCHAIN_TRIPLET)/libGLESv2.so, \
	-lGLESv2, \
	opengl))

$(eval $(call register-native-chroot-module, \
	egl, \
	/usr/include/EGL, \
	/usr/lib/$(TARGET_TOOLCHAIN_TRIPLET)/libEGL.so, \
	-lEGL, \
	opengl))


$(eval $(call register-native-chroot-module, \
	x11, \
	/usr/include/X11, \
	/usr/lib/$(TARGET_TOOLCHAIN_TRIPLET)/libX11.so, \
	-lX11 \
	$(empty)))

# Declare linux module if we have headers
ifneq ("$(wildcard /lib/modules/$(TARGET_LINUX_RELEASE)/build)","")
  include $(CLEAR_VARS)
  LOCAL_MODULE := linux
  $(call local-register-prebuilt-overridable)
endif
