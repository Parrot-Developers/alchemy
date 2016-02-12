###############################################################################
## @file autotools-rules.mk
## @author Y.M. Morgan
## @date 2012/07/13
##
## Build a module using autotools.
###############################################################################

###############################################################################
###############################################################################

ifeq ("$(strip $(LOCAL_AUTOTOOLS_CONFIGURE_SCRIPT))","")
  LOCAL_AUTOTOOLS_CONFIGURE_SCRIPT := configure
endif

# This file is included several times, define macros only once
# (mainly to improve perf)
ifndef __autotools-macros

# Patch libtool to make it work properly for cross-compilation.
# Modify the libdir in .la files installed in staging dir so that they reference
# the staging dir and not the final dir. Do this only if dest dir is not empty
# (in native build staging dir is the final dir specified in configure script).
# Use -rpath-link instead of -rpath to avoid hardcoding host path in binaries.
# See this link for more information :
# http://www.metastatic.org/text/libtool.html
define __autotools-libtool_patch
	$(Q) for f in `find $(PRIVATE_OBJ_DIR) -name libtool -o -name ltmain.sh`; do \
		echo "Patching $$f"; \
		$(if $($(PRIVATE_MODE)AUTOTOOLS_INSTALL_DESTDIR), \
			sed -i.bak -e "s|^libdir='\$$install_libdir'|libdir='\$${install_libdir:\+$($(PRIVATE_MODE)OUT_STAGING)\$$install_libdir}'|1" $$f; \
		) \
		sed -i.bak \
			-e 's|\({\?wl}\?\)-\+rpath|\1-rpath-link|1' \
			-e 's|need_relink=yes|need_relink=no|1' \
			$$f; \
		rm -f $$f.bak; \
	done
endef

# Simulate that some files are up to date to avoid internal reconfiguration
# that will likely fail because env or libtool patches are not correct
define __autotools-hook-pre-clean
	$(Q) if [ -d $(PRIVATE_OBJ_DIR) ]; then find $(PRIVATE_OBJ_DIR) -name config.status -exec touch {} \; ; fi
	$(Q) if [ -d $(PRIVATE_OBJ_DIR) ]; then find $(PRIVATE_OBJ_DIR) -name Makefile -exec touch {} \; ; fi
endef

endif # ifndef __autotools-macros

###############################################################################
## Add compilation/linker flags.
###############################################################################

# Add flags in environment
ifneq ("$(strip $(__external-add_CFLAGS))","")
  LOCAL_AUTOTOOLS_CONFIGURE_ENV += ASFLAGS="$$ASFLAGS $(__external-add_ASFLAGS)"
endif

ifneq ("$(strip $(__external-add_CFLAGS))","")
  LOCAL_AUTOTOOLS_CONFIGURE_ENV += CFLAGS="$$CFLAGS $(__external-add_CFLAGS)"
endif

ifneq ("$(strip $(__external-add_CXXFLAGS))","")
  LOCAL_AUTOTOOLS_CONFIGURE_ENV += CXXFLAGS="$$CXXFLAGS $(__external-add_CXXFLAGS)"
endif

ifneq ("$(strip $(__external-add_LDFLAGS))","")
  LOCAL_AUTOTOOLS_CONFIGURE_ENV += LDFLAGS="$$LDFLAGS $(__external-add_LDFLAGS)"
  LOCAL_AUTOTOOLS_CONFIGURE_ENV += DYN_LDFLAGS="$$DYN_LDFLAGS $(__external-add_LDFLAGS)"
endif

ifneq ("$(USE_AUTOTOOLS_CACHE)","0")
ifeq ("$(mode_host)","")
  LOCAL_AUTOTOOLS_CONFIGURE_ARGS += --config-cache
endif
endif

ifeq ("$(LOCAL_USE_CLANG)","1")
ifneq ("$(USE_CLANG)","1")
  LOCAL_AUTOTOOLS_CONFIGURE_ENV += CC="$(LOCAL_CLANG_PATH)/clang"
  LOCAL_AUTOTOOLS_CONFIGURE_ENV += CXX="$(LOCAL_CLANG_PATH)/clang++"
endif
endif

###############################################################################
## Default commands
###############################################################################

# This file is included several times, define macros only once
# (mainly to improve perf)
ifndef __autotools-macros

ifneq ("$(USE_AUTOTOOLS_CACHE)","0")
  __autotools-target-copy-cache = @cp -af $(__autotools-target-cache-file) $(PRIVATE_OBJ_DIR)/config.cache
else
  __autotools-target-copy-cache =
endif

define __autotools-default-cmd-configure
	$(if $(call streq,$(PRIVATE_MODE),TARGET_),$(__autotools-target-copy-cache))
	$(Q) cd $(PRIVATE_OBJ_DIR) && \
		$($(PRIVATE_MODE)AUTOTOOLS_CONFIGURE_ENV) $(PRIVATE_CONFIGURE_ENV) \
		$(PRIVATE_SRC_DIR)/$(PRIVATE_CONFIGURE_SCRIPT) \
		$($(PRIVATE_MODE)AUTOTOOLS_CONFIGURE_ARGS) $(PRIVATE_CONFIGURE_ARGS)
endef

define __autotools-default-cmd-build
	$(Q) $($(PRIVATE_MODE)AUTOTOOLS_MAKE_ENV) $(PRIVATE_MAKE_BUILD_ENV) \
		$(MAKE) -C $(PRIVATE_OBJ_DIR) \
		$($(PRIVATE_MODE)AUTOTOOLS_MAKE_ARGS) $(PRIVATE_MAKE_BUILD_ARGS)
endef

define __autotools-default-cmd-install
	$(Q) $($(PRIVATE_MODE)AUTOTOOLS_MAKE_ENV) $(PRIVATE_MAKE_INSTALL_ENV) \
		$(MAKE) -C $(PRIVATE_OBJ_DIR) \
		$($(PRIVATE_MODE)AUTOTOOLS_MAKE_ARGS) $(PRIVATE_MAKE_INSTALL_ARGS) install
endef

# Force success for command in case "uninstall" or "clean" is not supported
# or Makefile not present
define __autotools-default-cmd-clean
	$(Q) if [ -f $(PRIVATE_OBJ_DIR)/Makefile ]; then \
		$($(PRIVATE_MODE)AUTOTOOLS_MAKE_ENV) $(PRIVATE_MAKE_INSTALL_ENV) \
			$(MAKE) --keep-going --ignore-errors -C $(PRIVATE_OBJ_DIR) \
			$($(PRIVATE_MODE)AUTOTOOLS_MAKE_ARGS) $(PRIVATE_MAKE_INSTALL_ARGS) \
			uninstall || echo "Ignoring uninstall errors"; \
		$($(PRIVATE_MODE)AUTOTOOLS_MAKE_ENV) $(PRIVATE_MAKE_INSTALL_ENV) \
			$(MAKE) --keep-going --ignore-errors -C $(PRIVATE_OBJ_DIR) \
			$($(PRIVATE_MODE)AUTOTOOLS_MAKE_ARGS) \
			clean || echo "Ignoring clean errors"; \
	fi;
endef

endif # ifndef __autotools-macros

###############################################################################
###############################################################################

# Because autootools is widely used for generic build to not try to support
# out ouf source build
generic-build-out-of-src := 0

include $(BUILD_SYSTEM)/generic-rules.mk

# Restart configuration step if configure file has changed
# Note: if configure file is in an archive the wildcard test will fail the
# first time, but it is not a problem. The important thing is to detect by
# ourself that the configure file is newer.
ifneq ("$(wildcard $(src_dir)/$(LOCAL_AUTOTOOLS_CONFIGURE_SCRIPT))","")
$(configured_file): $(src_dir)/$(LOCAL_AUTOTOOLS_CONFIGURE_SCRIPT)
endif

# Force unpack/configure if configure file is missing
# Assume it is a real autottols if LOCAL_AUTOTOOLS_CMD_CONFIGURE is not redefined
ifeq ("$(value LOCAL_AUTOTOOLS_CMD_CONFIGURE)","")
ifeq ("$(wildcard $(src_dir)/$(LOCAL_AUTOTOOLS_CONFIGURE_SCRIPT))","")
$(call delete-one-done-file,$(unpacked_file))
$(call delete-one-done-file,$(configured_file))
endif
endif

# Restart configuration step if configure cache file has changed
ifneq ("$(USE_AUTOTOOLS_CACHE)","0")
ifeq ("$(mode_host)","")
$(configured_file): $(__autotools-target-cache-file)
endif
endif

# Setup commands
$(LOCAL_TARGETS): PRIVATE_MSG := $(if $(mode_host),Host )Autotools
$(LOCAL_TARGETS): PRIVATE_CMD_PREFIX := AUTOTOOLS
$(LOCAL_TARGETS): PRIVATE_DEFAULT_CMD_CONFIGURE := __autotools-default-cmd-configure
$(LOCAL_TARGETS): PRIVATE_DEFAULT_CMD_BUILD := __autotools-default-cmd-build
$(LOCAL_TARGETS): PRIVATE_DEFAULT_CMD_INSTALL := __autotools-default-cmd-install
$(LOCAL_TARGETS): PRIVATE_DEFAULT_CMD_CLEAN := __autotools-default-cmd-clean

# Internal hooks to be applied before/after steps.
$(LOCAL_TARGETS): PRIVATE_HOOK_POST_CONFIGURE := __autotools-libtool_patch
$(LOCAL_TARGETS): PRIVATE_HOOK_PRE_CLEAN := __autotools-hook-pre-clean

# Variables needed by default commands
$(LOCAL_TARGETS): PRIVATE_CONFIGURE_ENV := $(LOCAL_AUTOTOOLS_CONFIGURE_ENV)
$(LOCAL_TARGETS): PRIVATE_CONFIGURE_ARGS := $(LOCAL_AUTOTOOLS_CONFIGURE_ARGS)
$(LOCAL_TARGETS): PRIVATE_CONFIGURE_SCRIPT := $(LOCAL_AUTOTOOLS_CONFIGURE_SCRIPT)
$(LOCAL_TARGETS): PRIVATE_MAKE_BUILD_ENV := $(LOCAL_AUTOTOOLS_MAKE_BUILD_ENV)
$(LOCAL_TARGETS): PRIVATE_MAKE_BUILD_ARGS := $(LOCAL_AUTOTOOLS_MAKE_BUILD_ARGS)
$(LOCAL_TARGETS): PRIVATE_MAKE_INSTALL_ENV := $(LOCAL_AUTOTOOLS_MAKE_INSTALL_ENV)
$(LOCAL_TARGETS): PRIVATE_MAKE_INSTALL_ARGS := $(LOCAL_AUTOTOOLS_MAKE_INSTALL_ARGS)

# Macros of this file have been defined
__autotools-macros := 1
