###############################################################################
## @file classes/MESON/rules.mk
## @author Y.M. Morgan
## @date 2022/07/05
##
## Rules for MESON modules.
###############################################################################

ifeq ("$(MESON)","")
  $(error $(LOCAL_MODULE): meson not found)
endif

ifeq ("$(NINJA)","")
  $(error $(LOCAL_MODULE): ninja not found)
endif

###############################################################################
###############################################################################

_module_msg := $(if $(_mode_host),Host )Meson

_module_def_cmd_configure := _meson-def-cmd-configure
_module_def_cmd_build := _meson-def-cmd-build
_module_def_cmd_install := _meson-def-cmd-install
_module_def_cmd_clean := _meson-def-cmd-clean

# Variables needed by default commands
$(LOCAL_TARGETS): PRIVATE_CONFIGURE_ENV := $(LOCAL_MESON_CONFIGURE_ENV)
$(LOCAL_TARGETS): PRIVATE_CONFIGURE_ARGS := $(LOCAL_MESON_CONFIGURE_ARGS)
$(LOCAL_TARGETS): PRIVATE_BUILD_ENV := $(LOCAL_MESON_BUILD_ENV)
$(LOCAL_TARGETS): PRIVATE_BUILD_ARGS := $(LOCAL_MESON_BUILD_ARGS)
$(LOCAL_TARGETS): PRIVATE_INSTALL_ENV := $(LOCAL_MESON_INSTALL_ENV)
$(LOCAL_TARGETS): PRIVATE_INSTALL_ARGS := $(LOCAL_MESON_INSTALL_ARGS)
$(LOCAL_TARGETS): PRIVATE_CFLAGS :=  $(_external_add_CFLAGS)
$(LOCAL_TARGETS): PRIVATE_CXXFLAGS :=  $(_external_add_CXXFLAGS)
$(LOCAL_TARGETS): PRIVATE_LDFLAGS :=  $(_external_add_LDFLAGS)

include $(BUILD_SYSTEM)/classes/GENERIC/rules.mk
