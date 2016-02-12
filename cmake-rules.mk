###############################################################################
## @file cmake-rules.mk
## @author Y.M. Morgan
## @date 2013/07/24
##
## Build a module using cmake.
###############################################################################

ifeq ("$(CMAKE)","")
  $(error $(LOCAL_MODULE): cmake not found)
endif

###############################################################################
## Add compilation/linker flags.
###############################################################################

# Add flags in arguments (ALCHEMY_EXTRA are added by the toolchain file)
ifneq ("$(strip $(__external-add_ASFLAGS))","")
  LOCAL_CMAKE_CONFIGURE_ARGS += -DALCHEMY_EXTRA_AS_FLAGS="$(__external-add_ASFLAGS)"
endif

ifneq ("$(strip $(__external-add_CFLAGS))","")
  LOCAL_CMAKE_CONFIGURE_ARGS += -DALCHEMY_EXTRA_C_FLAGS="$(__external-add_CFLAGS)"
endif

ifneq ("$(strip $(__external-add_CXXFLAGS))","")
  LOCAL_CMAKE_CONFIGURE_ARGS += -DALCHEMY_EXTRA_CXX_FLAGS="$(__external-add_CXXFLAGS)"
endif

ifneq ("$(strip $(__external-add_LDFLAGS))","")
  LOCAL_CMAKE_CONFIGURE_ARGS += -DALCHEMY_EXTRA_EXE_LINKER_FLAGS="$(__external-add_LDFLAGS)"
  LOCAL_CMAKE_CONFIGURE_ARGS += -DALCHEMY_EXTRA_SHARED_LINKER_FLAGS="$(__external-add_LDFLAGS)"
  LOCAL_CMAKE_CONFIGURE_ARGS += -DALCHEMY_EXTRA_MODULE_LINKER_FLAGS="$(__external-add_LDFLAGS)"
endif

###############################################################################
## Default commands
###############################################################################

# This file is included several times, define macros only once
# (mainly to improve perf)
ifndef __cmake-macros

define __cmake-default-cmd-configure
	@mkdir -p $(PRIVATE_OBJ_DIR)
	$(Q) cd $(PRIVATE_OBJ_DIR) && rm -f CMakeCache.txt && \
		$(PKG_CONFIG_ENV) $(CMAKE) \
			-DCMAKE_TOOLCHAIN_FILE="$(CMAKE_TOOLCHAIN_FILE)" \
			$(CMAKE_CONFIGURE_ARGS) $(PRIVATE_CONFIGURE_ARGS) \
			$(PRIVATE_SRC_DIR)
endef

define __cmake-default-cmd-build
	$(Q) $(MAKE) -C $(PRIVATE_OBJ_DIR) \
		$(CMAKE_MAKE_ARGS) $(PRIVATE_MAKE_BUILD_ARGS)
endef

define __cmake-default-cmd-install
	$(Q) $(MAKE) -C $(PRIVATE_OBJ_DIR) \
		$(CMAKE_MAKE_ARGS) $(PRIVATE_MAKE_INSTALL_ARGS) install/fast
endef

# Force success for command in case "uninstall" or "clean" is not supported
# or Makefile not present
define __cmake-default-cmd-clean
	$(Q) if [ -f $(PRIVATE_OBJ_DIR)/Makefile ]; then \
		$(MAKE) --keep-going --ignore-errors -C $(PRIVATE_OBJ_DIR) \
			$(CMAKE_MAKE_ARGS) $(PRIVATE_MAKE_INSTALL_ARGS) \
			uninstall || echo "Ignoring uninstall errors"; \
		$(MAKE) --keep-going --ignore-errors -C $(PRIVATE_OBJ_DIR) \
			$(CMAKE_MAKE_ARGS) \
			clean || echo "Ignoring clean errors"; \
	fi;
endef

endif # ifndef __cmake-macros

###############################################################################
###############################################################################

# Build out of source tree (even for unpacked archives)
generic-build-out-of-src := 1

include $(BUILD_SYSTEM)/generic-rules.mk

# Generate cmake toolchain file before configuring
$(configured_file): $(CMAKE_TOOLCHAIN_FILE)

# Setup commands
$(LOCAL_TARGETS): PRIVATE_MSG := CMake
$(LOCAL_TARGETS): PRIVATE_CMD_PREFIX := CMAKE
$(LOCAL_TARGETS): PRIVATE_DEFAULT_CMD_CONFIGURE := __cmake-default-cmd-configure
$(LOCAL_TARGETS): PRIVATE_DEFAULT_CMD_BUILD := __cmake-default-cmd-build
$(LOCAL_TARGETS): PRIVATE_DEFAULT_CMD_INSTALL := __cmake-default-cmd-install
$(LOCAL_TARGETS): PRIVATE_DEFAULT_CMD_CLEAN := __cmake-default-cmd-clean


# Variables needed by default commands
$(LOCAL_TARGETS): PRIVATE_CONFIGURE_ARGS := $(LOCAL_CMAKE_CONFIGURE_ARGS)
$(LOCAL_TARGETS): PRIVATE_MAKE_BUILD_ARGS := $(LOCAL_CMAKE_MAKE_BUILD_ARGS)
$(LOCAL_TARGETS): PRIVATE_MAKE_INSTALL_ARGS := $(LOCAL_CMAKE_MAKE_INSTALL_ARGS)

# Macros of this file have been defined
__cmake-macros := 1
