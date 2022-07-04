###############################################################################
## @file classes/MESON/setup.mk
## @author Y.M. Morgan
## @date 2022/07/05
##
## Setup MESON modules.
###############################################################################

# Update host compilation path
_meson_host_path := $(_autotools_host_path)

# Update target compilation path (use host binaries)
_meson_target_path := $(_meson_host_path)

ifndef MESON
  MESON := $(shell (which $(HOME)/.local/bin/meson || which meson) 2>/dev/null)
endif

ifndef NINJA
  NINJA := $(shell which ninja 2>/dev/null)
endif

ifeq ("$(V)","0")
  NINJA_VERBOSE :=
else
  NINJA_VERBOSE := -v
endif

###############################################################################
# Host variable setup.
###############################################################################

HOST_MESON_CONFIGURE_ENV := \
	PATH="$(_meson_host_path)" \

# Only compile static libraries so we don't have to change LD_LIBRARY_PATH
HOST_MESON_CONFIGURE_ARGS := \
	--prefix="$(HOST_AUTOTOOLS_CONFIGURE_PREFIX)" \
	--sysconfdir="$(HOST_AUTOTOOLS_CONFIGURE_SYSCONFDIR)" \
	--buildtype=debugoptimized \
	--default-library=static \
	--prefer-static

HOST_MESON_BUILD_ENV := \
	PATH="$(_meson_host_path)"

HOST_MESON_BUILD_ARGS :=

HOST_MESON_INSTALL_ENV := \
	PATH="$(_meson_host_path)" \
	DESTDIR="$(HOST_AUTOTOOLS_INSTALL_DESTDIR)"

HOST_MESON_INSTALL_ARGS :=

###############################################################################
# Target variable setup.
###############################################################################

TARGET_MESON_CONFIGURE_ARGS := \
	--prefix="$(TARGET_AUTOTOOLS_CONFIGURE_PREFIX)" \
	--sysconfdir="$(TARGET_AUTOTOOLS_CONFIGURE_SYSCONFDIR)" \
	--buildtype=debugoptimized

ifneq ("$(TARGET_DEFAULT_BIN_DESTDIR)","$(TARGET_ROOT_DESTDIR)/bin")
TARGET_MESON_CONFIGURE_ARGS += \
	--bindir="$(TARGET_AUTOTOOLS_CONFIGURE_BINDIR)"
endif

ifneq ("$(TARGET_DEFAULT_LIB_DESTDIR)","$(TARGET_ROOT_DESTDIR)/lib")
TARGET_MESON_CONFIGURE_ARGS += \
	--libdir="$(TARGET_AUTOTOOLS_CONFIGURE_LIBDIR)"
endif

# Force static compilation if required
ifeq ("$(TARGET_FORCE_STATIC)","1")
TARGET_MESON_CONFIGURE_ARGS += \
	--default-library=static \
	--prefer-static
endif

TARGET_MESON_BUILD_ENV := \
	PATH="$(_meson_target_path)"

TARGET_MESON_BUILD_ARGS :=

TARGET_MESON_INSTALL_ENV := \
	PATH="$(_meson_target_path)" \
	DESTDIR="$(TARGET_AUTOTOOLS_INSTALL_DESTDIR)"

TARGET_MESON_INSTALL_ARGS :=

###############################################################################
# Host native file generation.
###############################################################################

# Flags
_meson_host_cflags := \
	$(call normalize-system-c-includes,$(HOST_GLOBAL_C_INCLUDES),HOST) \
	$(HOST_GLOBAL_CFLAGS)

_meson_host_cxxflags := \
	$(filter-out -std=%,$(_meson_host_cflags)) \
	$(HOST_GLOBAL_CXXFLAGS)

_meson_host_ldflags := \
	$(HOST_GLOBAL_LDFLAGS) $(HOST_GLOBAL_LDLIBS)

# Sed command to update template
define _meson_native-compile-conf-sed
	-e "s%@HOST_CC@%$(HOST_CC)%g" \
	-e "s%@HOST_CXX@%$(HOST_CXX)%g" \
	-e "s%@HOST_AR@%$(HOST_AR)%g" \
	-e "s%@HOST_STRIP@%$(HOST_STRIP)%g" \
	-e "s%@PKGCONFIG_BIN@%$(PKGCONFIG_BIN)%g" \
	\
	-e "s%@MESON_C_ARGS@%$(call make-sq-comma-list,$(_meson_host_cflags) $(PRIVATE_CFLAGS))%g" \
	-e "s%@MESON_C_LINK_ARGS@%$(call make-sq-comma-list,$(_meson_host_ldflags) $(PRIVATE_LDFLAGS))%g" \
	-e "s%@MESON_CPP_ARGS@%$(call make-sq-comma-list,$(_meson_host_cxxflags) $(PRIVATE_CXXFLAGS))%g" \
	-e "s%@MESON_CPP_LINK_ARGS@%$(call make-sq-comma-list,$(_meson_host_ldflags) $(PRIVATE_LDFLAGS))%g" \
	\
	-e "s%@HOST_OUT_STAGING@%$(HOST_OUT_STAGING)%g" \
	-e "s%@HOST_PKG_CONFIG_PATH@%$(HOST_PKG_CONFIG_PATH)%g" \
	\
	$(BUILD_SYSTEM)/classes/MESON/native-compile.conf.in
endef

###############################################################################
# Target cross file generation.
###############################################################################

# System
ifeq ("$(TARGET_OS)","linux")
  ifeq ("$(TARGET_OS_FLAVOUR)","android")
    _meson_target_system := android
  else
    _meson_target_system := linux
  endif
else
  _meson_target_system := $(TARGET_OS)
endif

# Cpu
ifeq ("$(TARGET_ARCH)","aarch64")
  _meson_target_cpu_family := aarch64
  _meson_target_cpu := armv8
else ifeq ($(TARGET_ARCH),arm)
  _meson_target_cpu_family := arm
  _meson_target_cpu := armv7
else ifeq ($(TARGET_ARCH),x86)
  _meson_target_cpu_family := x86
  _meson_target_cpu := i686
else ifeq ($(TARGET_ARCH),x64)
  _meson_target_cpu_family := x86_64
  _meson_target_cpu := x86_64
else
  _meson_target_cpu_family := $(TARGET_ARCH)
  _meson_target_cpu := $(TARGET_CPU)
endif

# Endianess
_meson_target_endian := little

# Flags
_meson_target_cflags := \
	$(call normalize-system-c-includes,$(TARGET_GLOBAL_C_INCLUDES),TARGET) \
	$(TARGET_GLOBAL_CFLAGS)

_meson_target_cxxflags := \
	$(filter-out -std=%,$(_meson_target_cflags)) \
	$(TARGET_GLOBAL_CXXFLAGS)

_meson_target_ldflags := \
	$(TARGET_GLOBAL_LDFLAGS) $(TARGET_GLOBAL_LDLIBS)

# On yocto, the CC and CXX can contains arguments which is invalid for toolchain
# files: we split the command and move arguments to CFLAGS / CXXFLAGS
ifeq ("$(TARGET_OS_FLAVOUR)","yocto")
  _meson_target_cc := $(call first,$(TARGET_CC))
  _meson_target_cxx := $(call first,$(TARGET_CXX))

  _meson_target_cflags := $(call rest,$(TARGET_CC)) $(_meson_target_cflags)
  _meson_target_cxxflags := $(call rest,$(TARGET_CXX)) $(_meson_target_cxxflags)
  _meson_target_ldflags := $(call rest,$(TARGET_LD)) $(_meson_target_ldflags)
else
  _meson_target_cc := $(TARGET_CC)
  _meson_target_cxx := $(TARGET_CXX)
endif

# Sed command to update template
define _meson_cross-compile-conf-sed
	-e "s%@TARGET_CC@%$(_meson_target_cc)%g" \
	-e "s%@TARGET_CXX@%$(_meson_target_cxx)%g" \
	-e "s%@TARGET_AR@%$(TARGET_AR)%g" \
	-e "s%@TARGET_STRIP@%$(TARGET_STRIP)%g" \
	-e "s%@TARGET_STRIP@%$(TARGET_STRIP)%g" \
	-e "s%@PKGCONFIG_BIN@%$(PKGCONFIG_BIN)%g" \
	\
	-e "s%@MESON_C_ARGS@%$(call make-sq-comma-list,$(_meson_target_cflags) $(PRIVATE_CFLAGS))%g" \
	-e "s%@MESON_C_LINK_ARGS@%$(call make-sq-comma-list,$(_meson_target_ldflags) $(PRIVATE_LDFLAGS))%g" \
	-e "s%@MESON_CPP_ARGS@%$(call make-sq-comma-list,$(_meson_target_cxxflags) $(PRIVATE_CXXFLAGS))%g" \
	-e "s%@MESON_CPP_LINK_ARGS@%$(call make-sq-comma-list,$(_meson_target_ldflags) $(PRIVATE_LDFLAGS))%g" \
	\
	-e "s%@TARGET_OUT_STAGING@%$(TARGET_OUT_STAGING)%g" \
	-e "s%@TARGET_PKG_CONFIG_PATH@%$(TARGET_PKG_CONFIG_PATH)%g" \
	\
	-e "s%@MESON_SYSTEM@%$(_meson_target_system)%g" \
	-e "s%@MESON_CPU_FAMILY@%$(_meson_target_cpu_family)%g" \
	-e "s%@MESON_CPU@%$(_meson_target_cpu)%g" \
	-e "s%@MESON_ENDIAN@%$(_meson_target_endian)%g" \
	\
	$(BUILD_SYSTEM)/classes/MESON/cross-compile.conf.in
endef

###############################################################################
## Commands macros.
###############################################################################

# Generate the native/cross compile configuration file from template
define _meson-gen-conf-file
	$(if $(PRIVATE_MODE_IS_HOST), \
		@sed $(_meson_native-compile-conf-sed) > $(PRIVATE_OBJ_DIR)/meson.conf \
		, \
		@sed $(_meson_cross-compile-conf-sed) > $(PRIVATE_OBJ_DIR)/meson.conf \
	)
endef

# Get the native/cross compile configuration file opetion to give to meson
define _meson-get-conf-file-args
	$(if $(PRIVATE_MODE_IS_HOST), \
		--native-file=$(PRIVATE_OBJ_DIR)/meson.conf \
		, \
		--cross-file=$(PRIVATE_OBJ_DIR)/meson.conf \
	)
endef

define _meson-def-cmd-configure
	@mkdir -p $(PRIVATE_OBJ_DIR)
	$(_meson-gen-conf-file)
	$(Q) cd $(PRIVATE_OBJ_DIR) && \
		$($(PRIVATE_MODE)_MESON_CONFIGURE_ENV) $(PRIVATE_CONFIGURE_ENV) \
		$(MESON) \
		$($(PRIVATE_MODE)_MESON_CONFIGURE_ARGS) $(PRIVATE_CONFIGURE_ARGS) \
		$(_meson-get-conf-file-args) \
		$(PRIVATE_OBJ_DIR) $(PRIVATE_SRC_DIR)
endef

# Parallel build issue: ninja and make will not share the number of parallel jobs
# https://github.com/ninja-build/ninja/issues/1139
define _meson-def-cmd-build
	$(Q) $($(PRIVATE_MODE)_MESON_BUILD_ENV) $(PRIVATE_BUILD_ENV) \
		$(NINJA) $(NINJA_VERBOSE) -C $(PRIVATE_OBJ_DIR) \
		$($(PRIVATE_MODE)_MESON_BUILD_ARGS) $(PRIVATE_BUILD_ARGS)
endef

define _meson-def-cmd-install
	$(Q) $($(PRIVATE_MODE)_MESON_INSTALL_ENV) $(PRIVATE_INSTALL_ENV) \
		$(NINJA) $(NINJA_VERBOSE) -C $(PRIVATE_OBJ_DIR) install \
		$($(PRIVATE_MODE)_MESON_INSTALL_ARGS) $(PRIVATE_INSTALL_ARGS)
endef

define _meson-def-cmd-clean
	$(Q) if [ -f $(PRIVATE_OBJ_DIR)/build.ninja ]; then \
		$($(PRIVATE_MODE)_MESON_INSTALL_ENV) $(PRIVATE_INSTALL_ENV) \
			$(NINJA) $(NINJA_VERBOSE) -k 0 -C $(PRIVATE_OBJ_DIR) uninstall \
			$($(PRIVATE_MODE)_MESON_INSTALL_ARGS) $(PRIVATE_INSTALL_ARGS) \
			|| echo "Ignoring uninstall errors"; \
		$($(PRIVATE_MODE)_MESON_INSTALL_ENV) $(PRIVATE_INSTALL_ENV) \
			$(NINJA) $(NINJA_VERBOSE) -k 0 -C $(PRIVATE_OBJ_DIR) clean \
			$($(PRIVATE_MODE)_MESON_INSTALL_ARGS) $(PRIVATE_INSTALL_ARGS) \
			|| echo "Ignoring clean errors"; \
	fi
endef
