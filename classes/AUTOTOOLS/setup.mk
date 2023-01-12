###############################################################################
## @file classes/AUTOTOOLS/setup.mk
## @author Y.M. Morgan
## @date 2012/09/21
##
## Setup AUTOTOOLS modules.
###############################################################################

###############################################################################
## Setup some internal stuff.
###############################################################################

# Get path to 'install' binary so we can override it in configure environment
# (we add the -p option to preserve timestamp of installed files)
_autotools_install_bin := $(shell which install 2>/dev/null)

# Update host compilation path
_autotools_host_path := $(call make-path-list, \
	$(HOST_OUT_STAGING)/bin \
	$(HOST_OUT_STAGING)/$(HOST_DEFAULT_BIN_DESTDIR) \
	$(call split-path-list,$(PATH)) \
)

# Update target compilation path (use host binaries)
_autotools_target_path := $(_autotools_host_path)

# Common arguments to configure
# * Avoid triggering regeneration of configure/Makefile.in. The regeneration
#   could cause issues because it would remove the patches we made in libtool
# * Disable locale support.
# * Disable documentation.
# * Don't display warning for unrecognized options (other disabled options may
#   not be actually supported).
_autotools_configure_args := \
	--disable-maintainer-mode \
	--disable-nls \
	--disable-gtk-doc \
	--disable-gtk-doc-html \
	--disable-doxygen-docs \
	--disable-doc \
	--disable-docs \
	--disable-documentation \
	--disable-option-checking

# Cache file for target
_autotools_target_cache_file := $(TARGET_OUT_BUILD)/autotools.cache

# - Force timestamp ordering of some generated files to make sure an automatic
#   autoreconf is not triggered
#   Only do it if the source dir is not LOCAL_PATH (so either extracted from
#   archive or copied in build directory)
#   No need to do that if a custom bootstrap is done
# - Use our own copy of config.sub to make sure we have an up to date version
#   for old packages that lack support for some platforms (aarch64, android...)
#   TODO: do the copy only if our script is newer (compare timestamp with -t)
define _autotools-hook-pre-configure
	$(if $(call strneq,$(PRIVATE_SRC_DIR),$(PRIVATE_PATH)), \
		$(Q) find $(PRIVATE_SRC_DIR) -name Makefile.am -exec touch {} \;$(endl) \
		$(Q) find $(PRIVATE_SRC_DIR) -name configure.ac -exec touch {} \;$(endl) \
		$(Q) find $(PRIVATE_SRC_DIR) -name configure.in -exec touch {} \;$(endl) \
		$(Q) find $(PRIVATE_SRC_DIR) -name aclocal.m4 -exec touch {} \;$(endl) \
		$(Q) find $(PRIVATE_SRC_DIR) -name config.h.in -exec touch {} \;$(endl) \
		$(Q) find $(PRIVATE_SRC_DIR) -name Makefile.in -exec touch {} \;$(endl) \
		$(Q) find $(PRIVATE_SRC_DIR) -name configure -exec touch {} \;$(endl) \
		$(Q) find $(PRIVATE_SRC_DIR) -name configure.sh -exec touch {} \;$(endl) \
		$(Q) find $(PRIVATE_SRC_DIR) -name config.sub -exec cp -af $(BUILD_SYSTEM)/scripts/config.sub {} \;$(endl) \
	)
endef

# Patch libtool to make it work properly for cross-compilation.
# - Modify the libdir in .la files installed in staging dir so that they reference
#   the staging dir and not the final dir. Do this only if dest dir is not empty
#   (in native build staging dir is the final dir specified in configure script).
# - Use -rpath-link instead of -rpath to avoid hardcoding host path in binaries.
# - Add more exception to flags that needs to be pass to the linker.
#   We search for the '-m*' excetion and add other (mainly for clang).
#   Another alternative would be to create wrapper with those flags.
#
# See this link for more information :
# http://www.metastatic.org/text/libtool.html
define _autotools-libtool-patch
	$(Q) for f in `find $(PRIVATE_OBJ_DIR) -name libtool -o -name ltmain.sh`; do \
		echo "Patching $$f"; \
		sed -i.bak \
			$(if $($(PRIVATE_MODE)_AUTOTOOLS_INSTALL_DESTDIR), \
				-e "s!^libdir='\$$install_libdir'!libdir='\$${install_libdir:\+$($(PRIVATE_MODE)_AUTOTOOLS_INSTALL_DESTDIR)\$$install_libdir}'!1" \
			) \
			-e 's!\({\?wl}\?\)-\+rpath!\1-rpath-link!1' \
			-e 's!need_relink=yes!need_relink=no!1' \
			-e 's!-m\*!-m\*|--sysroot=\*|-B\*|--gcc-toolchain=\*|--target=\*!1' \
			$$f; \
		rm -f $$f.bak; \
	done
endef

# Simulate that some files are up to date to avoid internal reconfiguration
# that will likely fail because env or libtool patches are not correct
define _autotools-hook-pre-clean
	$(Q) if [ -d $(PRIVATE_OBJ_DIR) ]; then find $(PRIVATE_OBJ_DIR) -name config.status -exec touch {} \; ; fi
	$(Q) if [ -d $(PRIVATE_OBJ_DIR) ]; then find $(PRIVATE_OBJ_DIR) -name Makefile -exec touch {} \; ; fi
endef

ifneq ("$(USE_AUTOTOOLS_CACHE)","0")
  _autotools-target-copy-cache = @cp -af $(_autotools-target-cache-file) $(PRIVATE_OBJ_DIR)/config.cache
else
  _autotools-target-copy-cache =
endif

define _autotools-def-cmd-configure
	$(if $(call streq,$(PRIVATE_MODE),TARGET),$(_autotools-target-copy-cache))
	$(Q) cd $(PRIVATE_OBJ_DIR) && \
		$($(PRIVATE_MODE)_AUTOTOOLS_CONFIGURE_ENV) $(PRIVATE_CONFIGURE_ENV) \
		$(PRIVATE_SRC_DIR)/$(PRIVATE_CONFIGURE_SCRIPT) \
		$($(PRIVATE_MODE)_AUTOTOOLS_CONFIGURE_ARGS) $(PRIVATE_CONFIGURE_ARGS)
endef

define _autotools-def-cmd-build
	$(Q) $($(PRIVATE_MODE)_AUTOTOOLS_MAKE_ENV) $(PRIVATE_MAKE_BUILD_ENV) \
		$(MAKE) -C $(PRIVATE_OBJ_DIR) \
		$($(PRIVATE_MODE)_AUTOTOOLS_MAKE_ARGS) $(PRIVATE_MAKE_BUILD_ARGS)
endef

define _autotools-def-cmd-install
	$(Q) $($(PRIVATE_MODE)_AUTOTOOLS_MAKE_ENV) $(PRIVATE_MAKE_INSTALL_ENV) \
		$(MAKE) -C $(PRIVATE_OBJ_DIR) \
		$($(PRIVATE_MODE)_AUTOTOOLS_MAKE_ARGS) $(PRIVATE_MAKE_INSTALL_ARGS) install
endef

# Force success for command in case "uninstall" or "clean" is not supported
# or Makefile not present
define _autotools-def-cmd-clean
	$(Q) if [ -f $(PRIVATE_OBJ_DIR)/Makefile ]; then \
		$($(PRIVATE_MODE)_AUTOTOOLS_MAKE_ENV) $(PRIVATE_MAKE_INSTALL_ENV) \
			$(MAKE) --keep-going --ignore-errors -C $(PRIVATE_OBJ_DIR) \
			$($(PRIVATE_MODE)_AUTOTOOLS_MAKE_ARGS) $(PRIVATE_MAKE_INSTALL_ARGS) \
			uninstall || echo "Ignoring uninstall errors"; \
		$($(PRIVATE_MODE)_AUTOTOOLS_MAKE_ENV) $(PRIVATE_MAKE_INSTALL_ENV) \
			$(MAKE) --keep-going --ignore-errors -C $(PRIVATE_OBJ_DIR) \
			$($(PRIVATE_MODE)_AUTOTOOLS_MAKE_ARGS) \
			clean || echo "Ignoring clean errors"; \
	fi;
endef

###############################################################################
## Variable used for autotools on host modules.
###############################################################################

# Setup flags
HOST_AUTOTOOLS_ASFLAGS := \
	$(HOST_GLOBAL_ASFLAGS)

HOST_AUTOTOOLS_CPPFLAGS := \
	$(call normalize-system-c-includes,$(HOST_GLOBAL_C_INCLUDES),HOST)

HOST_AUTOTOOLS_CFLAGS := \
	$(HOST_AUTOTOOLS_CPPFLAGS) \
	$(HOST_GLOBAL_CFLAGS)

HOST_AUTOTOOLS_CXXFLAGS := \
	$(filter-out -std=%,$(HOST_AUTOTOOLS_CFLAGS)) \
	$(HOST_GLOBAL_CXXFLAGS)

HOST_AUTOTOOLS_LDFLAGS := \
	$(HOST_GLOBAL_LDFLAGS) \
	$(HOST_GLOBAL_LDLIBS)

# Setup pkg-config
# Use packages from both HOST_OUT_STAGING and standard places
HOST_PKG_CONFIG_PATH := $(call make-path-list, \
	$(HOST_OUT_STAGING)/lib/pkgconfig \
	$(HOST_OUT_STAGING)/$(HOST_DEFAULT_LIB_DESTDIR)/pkgconfig \
)
HOST_PKG_CONFIG_ENV := \
	PKG_CONFIG="$(PKGCONFIG_BIN)" \
	PKG_CONFIG_PATH="$(HOST_PKG_CONFIG_PATH)" \
	PKG_CONFIG_SYSROOT_DIR=""

# Environment to use when executing configure script
HOST_AUTOTOOLS_CONFIGURE_ENV := \
	PATH="$(_autotools_host_path)" \
	AR="$(HOST_AR)" \
	AS="$(HOST_AS)" \
	LD="$(HOST_LD)" \
	NM="$(HOST_NM)" \
	CC="$(CCACHE) $(HOST_CC)" \
	GCC="$(CCACHE) $(HOST_CC)" \
	CXX="$(CCACHE) $(HOST_CXX)" \
	CPP="$(HOST_CPP)" \
	FC="$(HOST_FC)" \
	RANLIB="$(HOST_RANLIB)" \
	STRIP="$(HOST_STRIP)" \
	OBJCOPY="$(HOST_OBJCOPY)" \
	OBJDUMP="$(HOST_OBJDUMP)" \
	INSTALL="$(_autotools_install_bin) -p" \
	MANIFEST_TOOL=":" \
	ASFLAGS="$(HOST_AUTOTOOLS_ASFLAGS)" \
	CPPFLAGS="$(HOST_AUTOTOOLS_CPPFLAGS)" \
	CFLAGS="$(HOST_AUTOTOOLS_CFLAGS)" \
	CXXFLAGS="$(HOST_AUTOTOOLS_CXXFLAGS)" \
	LDFLAGS="$(HOST_AUTOTOOLS_LDFLAGS)" \
	BISON_PATH="$(BISON_BIN)" \
	XDG_DATA_DIRS=$(HOST_XDG_DATA_DIRS) \
	$(HOST_PKG_CONFIG_ENV)

ifeq ("$(HOST_OS)","windows")
  HOST_AUTOTOOLS_CONFIGURE_ENV += \
      WINDRES="$(HOST_WINDRES)" \
      RC="$(HOST_WINDRES)"
endif

HOST_AUTOTOOLS_CONFIGURE_PREFIX := $(HOST_OUT_STAGING)/$(HOST_ROOT_DESTDIR)
HOST_AUTOTOOLS_CONFIGURE_SYSCONFDIR := $(HOST_OUT_STAGING)/$(HOST_DEFAULT_ETC_DESTDIR)
HOST_AUTOTOOLS_INSTALL_DESTDIR :=

HOST_AUTOTOOLS_CONFIGURE_ARGS += \
	--prefix="$(HOST_AUTOTOOLS_CONFIGURE_PREFIX)" \
	--sysconfdir="$(HOST_AUTOTOOLS_CONFIGURE_SYSCONFDIR)"

# Only compile static libraries so we don't have to change LD_LIBRARY_PATH
HOST_AUTOTOOLS_CONFIGURE_ARGS += \
	--enable-static \
	--disable-shared

# Finally, add common arguments
HOST_AUTOTOOLS_CONFIGURE_ARGS += \
	$(_autotools_configure_args)

# Environment to use when executing make
# Use PKG_CONFIG_ENV in case a package needs automatic reconfiguration
HOST_AUTOTOOLS_MAKE_ENV := \
	PATH="$(_autotools_host_path)" \
	XDG_DATA_DIRS=$(HOST_XDG_DATA_DIRS) \
	$(HOST_PKG_CONFIG_ENV)

# Arguments to give to make
HOST_AUTOTOOLS_MAKE_ARGS := DESTDIR="$(HOST_AUTOTOOLS_INSTALL_DESTDIR)"

# Quiet flags
ifeq ("$(V)","0")
  HOST_AUTOTOOLS_CONFIGURE_ARGS += --quiet --enable-silent-rules
  HOST_AUTOTOOLS_MAKE_ENV += LIBTOOLFLAGS="--quiet"
  HOST_AUTOTOOLS_MAKE_ARGS += -s --no-print-directory
endif

###############################################################################
## Variable used for autotools on target modules.
###############################################################################

# Setup flags
TARGET_AUTOTOOLS_ASFLAGS := \
	$(TARGET_GLOBAL_ASFLAGS)

TARGET_AUTOTOOLS_CPPFLAGS := \
	$(filter --sysroot=%,$(TARGET_GLOBAL_CFLAGS)) \
	$(call normalize-system-c-includes,$(TARGET_GLOBAL_C_INCLUDES),TARGET)

TARGET_AUTOTOOLS_CFLAGS := \
	$(TARGET_AUTOTOOLS_CPPFLAGS) \
	$(TARGET_GLOBAL_CFLAGS)

TARGET_AUTOTOOLS_CXXFLAGS := \
	$(filter-out -std=%,$(TARGET_AUTOTOOLS_CFLAGS)) \
	$(TARGET_GLOBAL_CXXFLAGS)

TARGET_AUTOTOOLS_LDFLAGS := \
	$(TARGET_GLOBAL_LDFLAGS) \
	$(TARGET_GLOBAL_LDLIBS)

_target_pkg_config_subdirs := \
	lib/$(TARGET_TOOLCHAIN_TRIPLET)/pkgconfig \
	lib/pkgconfig \
	$(TARGET_DEFAULT_LIB_DESTDIR)/$(TARGET_TOOLCHAIN_TRIPLET)/pkgconfig \
	$(TARGET_DEFAULT_LIB_DESTDIR)/pkgconfig

ifndef TARGET_PKG_CONFIG_PATH
  TARGET_PKG_CONFIG_PATH :=
endif

_target_pkg_config_dirs :=
$(foreach __dir,$(TARGET_OUT_STAGING) $(TARGET_SDK_DIRS), \
	$(foreach __dir2,$(_target_pkg_config_subdirs), \
		$(eval _target_pkg_config_dirs += $(__dir)/$(__dir2)) \
	) \
)
TARGET_PKG_CONFIG_PATH := $(call make-path-list, \
	$(call split-path-list,$(TARGET_PKG_CONFIG_PATH)) \
	$(_target_pkg_config_dirs) \
)

# Setup pkg-config
# Prevent use of packages from the host by setting PKG_CONFIG_LIBDIR to the
# staging dir, assuming no .pc file is present there. Using an empty string
# does not work with pkgconf.
TARGET_PKG_CONFIG_ENV := \
	PKG_CONFIG="$(PKGCONFIG_BIN)" \
	PKG_CONFIG_PATH="$(TARGET_PKG_CONFIG_PATH)"
ifeq ("$(TARGET_OS_FLAVOUR)","native")
  TARGET_PKG_CONFIG_ENV += PKG_CONFIG_SYSROOT_DIR=""
else
  TARGET_PKG_CONFIG_ENV += PKG_CONFIG_SYSROOT_DIR="$(TARGET_OUT_STAGING)"
  TARGET_PKG_CONFIG_ENV += PKG_CONFIG_LIBDIR="$(TARGET_OUT_STAGING)"
endif

# Environment to use when executing configure script
TARGET_AUTOTOOLS_CONFIGURE_ENV := \
	PATH="$(_autotools_target_path)" \
	AR="$(TARGET_AR)" \
	AS="$(TARGET_AS)" \
	LD="$(TARGET_LD)" \
	NM="$(TARGET_NM)" \
	CC="$(CCACHE) $(TARGET_CC)" \
	GCC="$(CCACHE) $(TARGET_CC)" \
	CXX="$(CCACHE) $(TARGET_CXX)" \
	CPP="$(TARGET_CPP)" \
	FC="$(TARGET_FC)" \
	RANLIB="$(TARGET_RANLIB)" \
	STRIP="$(TARGET_STRIP)" \
	OBJCOPY="$(TARGET_OBJCOPY)" \
	OBJDUMP="$(TARGET_OBJDUMP)" \
	INSTALL="$(_autotools_install_bin) -p" \
	MANIFEST_TOOL=":" \
	CC_FOR_BUILD="$(HOST_CC)" \
	ASFLAGS="$(TARGET_AUTOTOOLS_ASFLAGS)" \
	CPPFLAGS="$(TARGET_AUTOTOOLS_CPPFLAGS)" \
	CFLAGS="$(TARGET_AUTOTOOLS_CFLAGS)" \
	CXXFLAGS="$(TARGET_AUTOTOOLS_CXXFLAGS)" \
	LDFLAGS="$(filter-out -lrt,$(TARGET_AUTOTOOLS_LDFLAGS))" \
	BISON_PATH="$(BISON_BIN)" \
	XDG_DATA_DIRS=$(TARGET_XDG_DATA_DIRS) \
	$(TARGET_PKG_CONFIG_ENV)

ifeq ("$(TARGET_OS)","windows")
  TARGET_AUTOTOOLS_CONFIGURE_ENV += \
      WINDRES="$(TARGET_WINDRES)" \
      RC="$(TARGET_WINDRES)"
endif

TARGET_AUTOTOOLS_CONFIGURE_ARGS :=

# Build/target triplet, nothing to do for native build TARGET_ARCH = HOST_ARCH
# For all other, force cross-compilation
# Autotools 'host' is the name of the machine on which the package will run
# and  we call it 'target'.
# Setting both '--host' and '--build' avoids the following warning:
# 'WARNING: If you wanted to set the --build type, don't use --host'
ifeq ("$(TARGET_OS_FLAVOUR)-$(TARGET_ARCH)","native-$(HOST_ARCH)")
  # Nothing to do let autotools in native mode
else
  ifndef GNU_BUILD_NAME
    GNU_BUILD_NAME := $(shell $(HOST_CC) -dumpmachine)
  endif
  ifndef GNU_TARGET_NAME
    GNU_TARGET_NAME := $(TARGET_TOOLCHAIN_TRIPLET)
  endif
  TARGET_AUTOTOOLS_CONFIGURE_ARGS += \
	--build="$(GNU_BUILD_NAME)" \
	--host="$(GNU_TARGET_NAME)"
endif

# Force static compilation if required
ifeq ("$(TARGET_FORCE_STATIC)","1")
  TARGET_AUTOTOOLS_CONFIGURE_ARGS += \
	--enable-static \
	--disable-shared
endif

# For cross-compilation, use /$(TARGET_ROOT_DESTDIR) as prefix and install in our staging dir
# For native compilation, use staging as prefix and nothing for install dest dir
ifeq ("$(TARGET_OS_FLAVOUR)","native")
  ifndef TARGET_DEPLOY_ROOT
    TARGET_AUTOTOOLS_CONFIGURE_PREFIX := $(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR)
    TARGET_AUTOTOOLS_CONFIGURE_SYSCONFDIR := $(TARGET_OUT_STAGING)/$(TARGET_DEFAULT_ETC_DESTDIR)
    TARGET_AUTOTOOLS_CONFIGURE_BINDIR := $(TARGET_OUT_STAGING)/$(TARGET_DEFAULT_BIN_DESTDIR)
    TARGET_AUTOTOOLS_CONFIGURE_LIBDIR := $(TARGET_OUT_STAGING)/$(TARGET_DEFAULT_LIB_DESTDIR)
    TARGET_AUTOTOOLS_INSTALL_DESTDIR :=
  else
    TARGET_AUTOTOOLS_CONFIGURE_PREFIX := /$(TARGET_ROOT_DESTDIR)
    TARGET_AUTOTOOLS_CONFIGURE_SYSCONFDIR := /$(TARGET_DEFAULT_ETC_DESTDIR)
    TARGET_AUTOTOOLS_CONFIGURE_BINDIR := /$(TARGET_DEFAULT_BIN_DESTDIR)
    TARGET_AUTOTOOLS_CONFIGURE_LIBDIR := /$(TARGET_DEFAULT_LIB_DESTDIR)
    TARGET_AUTOTOOLS_INSTALL_DESTDIR := $(TARGET_OUT_STAGING)
  endif
else
  TARGET_AUTOTOOLS_CONFIGURE_PREFIX := /$(TARGET_ROOT_DESTDIR)
  TARGET_AUTOTOOLS_CONFIGURE_SYSCONFDIR := /$(TARGET_DEFAULT_ETC_DESTDIR)
  TARGET_AUTOTOOLS_CONFIGURE_BINDIR := /$(TARGET_DEFAULT_BIN_DESTDIR)
  TARGET_AUTOTOOLS_CONFIGURE_LIBDIR := /$(TARGET_DEFAULT_LIB_DESTDIR)
  TARGET_AUTOTOOLS_INSTALL_DESTDIR := $(TARGET_OUT_STAGING)
endif

# FIXME YACC should be bison -y (and test that BISON_BIN is not empty)
TARGET_AUTOTOOLS_CONFIGURE_ARGS += \
	--prefix="$(TARGET_AUTOTOOLS_CONFIGURE_PREFIX)" \
	--sysconfdir="$(TARGET_AUTOTOOLS_CONFIGURE_SYSCONFDIR)" \
	ac_cv_prog_YACC=$(BISON_BIN)

ifneq ("$(TARGET_DEFAULT_BIN_DESTDIR)","$(TARGET_ROOT_DESTDIR)/bin")
TARGET_AUTOTOOLS_CONFIGURE_ARGS += \
	--bindir="$(TARGET_AUTOTOOLS_CONFIGURE_BINDIR)"
endif

ifneq ("$(TARGET_DEFAULT_LIB_DESTDIR)","$(TARGET_ROOT_DESTDIR)/lib")
TARGET_AUTOTOOLS_CONFIGURE_ARGS += \
	--libdir="$(TARGET_AUTOTOOLS_CONFIGURE_LIBDIR)"
endif

# Finally, add common arguments
TARGET_AUTOTOOLS_CONFIGURE_ARGS += \
	$(_autotools_configure_args)

# Environment to use when executing make
# Use PKG_CONFIG_ENV in case a package needs automatic reconfiguration
TARGET_AUTOTOOLS_MAKE_ENV := \
	PATH="$(_autotools_host_path)" \
	XDG_DATA_DIRS=$(TARGET_XDG_DATA_DIRS) \
	$(TARGET_PKG_CONFIG_ENV)

# Arguments to give to make
TARGET_AUTOTOOLS_MAKE_ARGS := DESTDIR="$(TARGET_AUTOTOOLS_INSTALL_DESTDIR)"

# Quiet flags
ifeq ("$(V)","0")
  TARGET_AUTOTOOLS_CONFIGURE_ARGS += --quiet --enable-silent-rules
  TARGET_AUTOTOOLS_MAKE_ENV += LIBTOOLFLAGS="--quiet"
  TARGET_AUTOTOOLS_MAKE_ARGS += -s --no-print-directory
endif

###############################################################################
## Cache generation.
###############################################################################

$(_autotools_target_cache_file): $(BUILD_SYSTEM)/autotools-cache/configure
	@echo "Generating $(call path-from-top,$@)..."
	@mkdir -p $(TARGET_OUT_BUILD)/autotools-cache
	@rm -f $(TARGET_OUT_BUILD)/autotools-cache/config.cache
	$(Q) cd $(TARGET_OUT_BUILD)/autotools-cache && \
		$(TARGET_AUTOTOOLS_CONFIGURE_ENV) \
		$(BUILD_SYSTEM)/autotools-cache/configure \
		$(TARGET_AUTOTOOLS_CONFIGURE_ARGS) \
		--config-cache
	$(Q) sed -e "s/ac_cv_env_.*//g" \
		$(TARGET_OUT_BUILD)/autotools-cache/config.cache \
		> $@

_autotools-target-cache-file-clean:
	@rm -f $(_autotools_target_cache_file)

clobber: _autotools-target-cache-file-clean

###############################################################################
## For compatibility.
###############################################################################

PKG_CONFIG_ENV := $(TARGET_PKG_CONFIG_ENV)
AUTOTOOLS_CONFIGURE_ENV := $(TARGET_AUTOTOOLS_CONFIGURE_ENV)
AUTOTOOLS_CONFIGURE_ARGS := $(TARGET_AUTOTOOLS_CONFIGURE_ARGS)
AUTOTOOLS_CONFIGURE_PREFIX := $(TARGET_AUTOTOOLS_CONFIGURE_PREFIX)
AUTOTOOLS_CONFIGURE_SYSCONFDIR := $(TARGET_AUTOTOOLS_CONFIGURE_SYSCONFDIR)
AUTOTOOLS_INSTALL_DESTDIR := $(TARGET_AUTOTOOLS_INSTALL_DESTDIR)
AUTOTOOLS_MAKE_ENV := $(TARGET_AUTOTOOLS_MAKE_ENV)
AUTOTOOLS_MAKE_ARGS := $(TARGET_AUTOTOOLS_MAKE_ARGS)
TARGET_AUTOTOOLS_DYN_LDFLAGS := $(TARGET_AUTOTOOLS_LDFLAGS)
