###############################################################################
## @file classes/AUTOTOOLS/rules.mk
## @author Y.M. Morgan
## @date 2016/03/20
##
## Rules for AUTOTOOLS modules.
###############################################################################

ifeq ("$(strip $(LOCAL_AUTOTOOLS_CONFIGURE_SCRIPT))","")
  LOCAL_AUTOTOOLS_CONFIGURE_SCRIPT := configure
endif

###############################################################################
## Add compilation/linker flags.
###############################################################################

# Add flags in environment
ifneq ("$(strip $(_external_add_CFLAGS))","")
  LOCAL_AUTOTOOLS_CONFIGURE_ENV += ASFLAGS="$$ASFLAGS $(_external_add_ASFLAGS)"
endif

ifneq ("$(strip $(_external_add_CFLAGS))","")
  LOCAL_AUTOTOOLS_CONFIGURE_ENV += CFLAGS="$$CFLAGS $(_external_add_CFLAGS)"
endif

ifneq ("$(strip $(_external_add_CXXFLAGS))","")
  LOCAL_AUTOTOOLS_CONFIGURE_ENV += CXXFLAGS="$$CXXFLAGS $(_external_add_CXXFLAGS)"
endif

ifneq ("$(strip $(_external_add_LDFLAGS))","")
  LOCAL_AUTOTOOLS_CONFIGURE_ENV += LDFLAGS="$$LDFLAGS $(_external_add_LDFLAGS)"
endif

ifneq ("$(USE_AUTOTOOLS_CACHE)","0")
ifeq ("$(mode_host)","")
  LOCAL_AUTOTOOLS_CONFIGURE_ARGS += --config-cache
endif
endif

# TODO: CFLAGS/LDFLAGS needs to be updated as well.
ifneq ("$(_module_cc)","$($(_mode_prefix)_CC)")
  LOCAL_AUTOTOOLS_CONFIGURE_ENV += CC="$(_module_cc)"
endif
ifneq ("$(_module_cxx)","$($(_mode_prefix)_CXX)")
  LOCAL_AUTOTOOLS_CONFIGURE_ENV += CXX="$(_module_cxx)"
endif

###############################################################################
###############################################################################

_module_msg := $(if $(_mode_host),Host )Autotools

_module_def_cmd_configure := _autotools-def-cmd-configure
_module_def_cmd_build := _autotools-def-cmd-build
_module_def_cmd_install := _autotools-def-cmd-install
_module_def_cmd_clean := _autotools-def-cmd-clean

# No need to do the timestamp ordeing hook if a bootstrap is done
ifeq ("$(value LOCAL_CMD_BOOTSTRAP)","")
_module_hook_pre_configure := _autotools-hook-pre-configure
endif

_module_hook_post_configure := _autotools-libtool-patch
_module_hook_pre_clean := _autotools-hook-pre-clean

# Variables needed by default commands
$(LOCAL_TARGETS): PRIVATE_CONFIGURE_ENV := $(LOCAL_AUTOTOOLS_CONFIGURE_ENV)
$(LOCAL_TARGETS): PRIVATE_CONFIGURE_ARGS := $(LOCAL_AUTOTOOLS_CONFIGURE_ARGS)
$(LOCAL_TARGETS): PRIVATE_CONFIGURE_SCRIPT := $(LOCAL_AUTOTOOLS_CONFIGURE_SCRIPT)
$(LOCAL_TARGETS): PRIVATE_MAKE_BUILD_ENV := $(LOCAL_AUTOTOOLS_MAKE_BUILD_ENV)
$(LOCAL_TARGETS): PRIVATE_MAKE_BUILD_ARGS := $(LOCAL_AUTOTOOLS_MAKE_BUILD_ARGS)
$(LOCAL_TARGETS): PRIVATE_MAKE_INSTALL_ENV := $(LOCAL_AUTOTOOLS_MAKE_INSTALL_ENV)
$(LOCAL_TARGETS): PRIVATE_MAKE_INSTALL_ARGS := $(LOCAL_AUTOTOOLS_MAKE_INSTALL_ARGS)

include $(BUILD_SYSTEM)/classes/GENERIC/rules.mk

###############################################################################
###############################################################################

# Restart configuration step if configure file has changed
# Note: if configure file is in an archive the wildcard test will fail the
# first time, but it is not a problem. The important thing is to detect by
# ourself that the configure file is newer.
ifneq ("$(wildcard $(_generic_src_dir)/$(LOCAL_AUTOTOOLS_CONFIGURE_SCRIPT))","")
$(_module_configured_stamp_file): $(_generic_src_dir)/$(LOCAL_AUTOTOOLS_CONFIGURE_SCRIPT)
$(_generic_src_dir)/$(LOCAL_AUTOTOOLS_CONFIGURE_SCRIPT):
endif

# TODO
# Force unpack/configure if configure file is missing
# Assume it is a real autotools if LOCAL_AUTOTOOLS_CMD_CONFIGURE is not redefined
#ifeq ("$(value LOCAL_AUTOTOOLS_CMD_CONFIGURE)","")
#ifeq ("$(wildcard $(src_dir)/$(LOCAL_AUTOTOOLS_CONFIGURE_SCRIPT))","")
#$(call delete-one-done-file,$(unpacked_file))
#$(call delete-one-done-file,$(configured_file))
#endif
#endif

# Restart configuration step if configure cache file has changed
ifneq ("$(USE_AUTOTOOLS_CACHE)","0")
ifeq ("$(_mode_host)","")
$(_module_configured_stamp_file): $(_autotools-target-cache-file)
endif
endif
