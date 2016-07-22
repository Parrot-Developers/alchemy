###############################################################################
## @file classes/CMAKE/rules.mk
## @author Y.M. Morgan
## @date 2016/03/20
##
## Rules for CMAKE modules.
###############################################################################

ifeq ("$(CMAKE)","")
  $(error $(LOCAL_MODULE): cmake not found)
endif

###############################################################################
## Add compilation/linker flags.
###############################################################################

# Add flags in arguments (ALCHEMY_EXTRA are added by the toolchain file)
ifneq ("$(strip $(_external_add_ASFLAGS))","")
  LOCAL_CMAKE_CONFIGURE_ARGS += -DALCHEMY_EXTRA_ASM_FLAGS="$(_external_add_ASFLAGS)"
endif

ifneq ("$(strip $(_external_add_CFLAGS))","")
  LOCAL_CMAKE_CONFIGURE_ARGS += -DALCHEMY_EXTRA_C_FLAGS="$(_external_add_CFLAGS)"
endif

ifneq ("$(strip $(_external_add_CXXFLAGS))","")
  LOCAL_CMAKE_CONFIGURE_ARGS += -DALCHEMY_EXTRA_CXX_FLAGS="$(_external_add_CXXFLAGS)"
endif

ifneq ("$(strip $(_external_add_LDFLAGS))","")
  LOCAL_CMAKE_CONFIGURE_ARGS += -DALCHEMY_EXTRA_EXE_LINKER_FLAGS="$(_external_add_LDFLAGS)"
  LOCAL_CMAKE_CONFIGURE_ARGS += -DALCHEMY_EXTRA_SHARED_LINKER_FLAGS="$(_external_add_LDFLAGS)"
  LOCAL_CMAKE_CONFIGURE_ARGS += -DALCHEMY_EXTRA_MODULE_LINKER_FLAGS="$(_external_add_LDFLAGS)"
endif

###############################################################################
###############################################################################

_module_msg := $(if $(_mode_host),Host )CMake

_module_def_cmd_configure := _cmake-def-cmd-configure
_module_def_cmd_build := _cmake-def-cmd-build
_module_def_cmd_install := _cmake-def-cmd-install
_module_def_cmd_clean := _cmake-def-cmd-clean

# Variables needed by default commands
$(LOCAL_TARGETS): PRIVATE_CONFIGURE_ARGS := $(LOCAL_CMAKE_CONFIGURE_ARGS)
$(LOCAL_TARGETS): PRIVATE_MAKE_BUILD_ARGS := $(LOCAL_CMAKE_MAKE_BUILD_ARGS)
$(LOCAL_TARGETS): PRIVATE_MAKE_INSTALL_ARGS := $(LOCAL_CMAKE_MAKE_INSTALL_ARGS)

include $(BUILD_SYSTEM)/classes/GENERIC/rules.mk

###############################################################################
###############################################################################

# Generate cmake toolchain file before configuring
$(_module_configured_stamp_file): $($(_mode_prefix)_CMAKE_TOOLCHAIN_FILE)
