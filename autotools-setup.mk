###############################################################################
## @file autotools-setup.mk
## @author Y.M. Morgan
## @date 2012/09/21
###############################################################################

###############################################################################
## Setup some internal stuff.
###############################################################################

# Get path to 'install' binary so we can override it in configure environment
# (we add the -p option to preserve timestamp of installed files)
__autotools-install-bin := $(shell which install)

## Get path to 'pkg-config' binary
__autotools-pkg-config-bin := $(shell which pkg-config)

# Update host compilation path
__autotools-host-path := $(HOST_OUT_STAGING)/bin:$(HOST_OUT_STAGING)/usr/bin:$(PATH)

# Update target compilation path
__autotools-target-path := $(HOST_OUT_STAGING)/bin:$(HOST_OUT_STAGING)/usr/bin:$(PATH)

# Common arguments to configure
# * Avoid triggering regeneration of configure/Makefile.in. The regeneration
#   could cause issues because it would remove the patches we made in libtool
# * Disable locale support.
# * Disable documentation.
# * Don't display warning for unrecognized options (other disabled options may
#   not be actually supported).
__autotools-configure-args := \
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
__autotools-target-cache-file := $(TARGET_OUT_BUILD)/autotools.cache

###############################################################################
## Variable used for autotools on host modules.
###############################################################################

# Setup flags
HOST_AUTOTOOLS_ASFLAGS := $(HOST_GLOBAL_ASFLAGS)
HOST_AUTOTOOLS_CPPFLAGS := $(call normalize-system-c-includes,$(HOST_GLOBAL_C_INCLUDES))
HOST_AUTOTOOLS_CFLAGS := $(HOST_AUTOTOOLS_CPPFLAGS) $(HOST_GLOBAL_CFLAGS)
HOST_AUTOTOOLS_CXXFLAGS := $(filter-out -std=%,$(HOST_AUTOTOOLS_CFLAGS)) $(HOST_GLOBAL_CXXFLAGS)

# Setup pkg-config
# Use packages from both HOST_OUT_STAGING and standard places
HOST_PKG_CONFIG_ENV := \
	PKG_CONFIG="$(__autotools-pkg-config-bin)" \
	PKG_CONFIG_PATH="$(HOST_OUT_STAGING)/usr/lib/pkgconfig:$(HOST_OUT_STAGING)/lib/pkgconfig" \
	PKG_CONFIG_SYSROOT_DIR=""

# Environment to use when executing configure script
HOST_AUTOTOOLS_CONFIGURE_ENV := \
	PATH="$(__autotools-host-path)" \
	AR="$(HOST_AR)" \
	AS="$(HOST_AS)" \
	LD="$(HOST_LD)" \
	NM="$(HOST_NM)" \
	CC="$(CCACHE) $(HOST_CC)" \
	GCC="$(CCACHE) $(HOST_CC)" \
	CXX="$(CCACHE) $(HOST_CXX)" \
	CPP="$(HOST_CPP)" \
	RANLIB="$(HOST_RANLIB)" \
	STRIP="$(HOST_STRIP)" \
	OBJCOPY="$(HOST_OBJCOPY)" \
	OBJDUMP="$(HOST_OBJDUMP)" \
	INSTALL="$(__autotools-install-bin) -p" \
	MANIFEST_TOOL=":" \
	ASFLAGS="$(HOST_AUTOTOOLS_ASFLAGS)" \
	CPPFLAGS="$(HOST_AUTOTOOLS_CPPFLAGS)" \
	CFLAGS="$(HOST_AUTOTOOLS_CFLAGS)" \
	CXXFLAGS="$(HOST_AUTOTOOLS_CXXFLAGS)" \
	LDFLAGS="$(HOST_GLOBAL_LDFLAGS) $(HOST_GLOBAL_LDLIBS)" \
	DYN_LDFLAGS="$(HOST_GLOBAL_LDFLAGS_SHARED) $(HOST_GLOBAL_LDLIBS_SHARED)" \
	BISON_PATH="$(BISON_PATH)" \
	XDG_DATA_DIRS=$(HOST_XDG_DATA_DIRS) \
	$(HOST_PKG_CONFIG_ENV)

HOST_AUTOTOOLS_CONFIGURE_PREFIX := $(HOST_OUT_STAGING)/usr
HOST_AUTOTOOLS_CONFIGURE_SYSCONFDIR := $(HOST_OUT_STAGING)/etc
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
	$(__autotools-configure-args)

# Environment to use when executing make
# Use PKG_CONFIG_ENV in case a package needs automatic reconfiguration
HOST_AUTOTOOLS_MAKE_ENV := \
	PATH="$(__autotools-host-path)" \
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

ifeq ("$(USE_CLANG)","1")
module_compiler_flavour := clang
else
module_compiler_flavour := gcc
endif

# Setup compilations flags
TARGET_AUTOTOOLS_CPPFLAGS := $(call normalize-system-c-includes,$(TARGET_GLOBAL_C_INCLUDES))
TARGET_AUTOTOOLS_CFLAGS := $(TARGET_AUTOTOOLS_CPPFLAGS) $(TARGET_GLOBAL_CFLAGS) $(TARGET_GLOBAL_CFLAGS_$(module_compiler_flavour))
TARGET_AUTOTOOLS_CXXFLAGS := $(filter-out -std=%,$(TARGET_AUTOTOOLS_CFLAGS)) $(TARGET_GLOBAL_CXXFLAGS)
TARGET_AUTOTOOLS_LDFLAGS := $(TARGET_GLOBAL_LDFLAGS) $(TARGET_GLOBAL_LDLIBS) $(TARGET_GLOBAL_LDFLAGS_$(module_compiler_flavour))
TARGET_AUTOTOOLS_DYN_LDFLAGS := $(TARGET_GLOBAL_LDFLAGS_SHARED) $(TARGET_GLOBAL_LDLIBS_SHARED)

__target_pkg_config_path :=
$(foreach __dir,$(TARGET_OUT_STAGING) $(TARGET_SDK_DIRS), \
	$(eval __target_pkg_config_path := $(__target_pkg_config_path):$(__dir)/usr/lib/pkgconfig) \
	$(eval __target_pkg_config_path := $(__target_pkg_config_path):$(__dir)/lib/pkgconfig) \
	$(eval __target_pkg_config_path := $(__target_pkg_config_path):$(__dir)/usr/share/pkgconfig) \
	$(eval __target_pkg_config_path := $(__target_pkg_config_path):$(__dir)/usr/lib/$(TOOLCHAIN_TARGET_NAME)/pkgconfig) \
)

# Setup pkg-config
# Only use packages found in TARGET_OUT_STAGING by setting PKG_CONFIG_LIBDIR empty
TARGET_PKG_CONFIG_ENV := \
	PKG_CONFIG="$(__autotools-pkg-config-bin)" \
	PKG_CONFIG_PATH="$(__target_pkg_config_path)"
ifeq ("$(TARGET_OS_FLAVOUR)","native")
  TARGET_PKG_CONFIG_ENV += PKG_CONFIG_SYSROOT_DIR=""
else
  TARGET_PKG_CONFIG_ENV += PKG_CONFIG_SYSROOT_DIR="$(TARGET_OUT_STAGING)" \
			   PKG_CONFIG_LIBDIR=""
endif

# Environment to use when executing configure script
TARGET_AUTOTOOLS_CONFIGURE_ENV := \
	PATH="$(__autotools-target-path)" \
	AR="$(TARGET_AR)" \
	AS="$(TARGET_AS)" \
	LD="$(TARGET_LD)" \
	NM="$(TARGET_NM)" \
	CC="$(CCACHE) $(TARGET_CC)" \
	GCC="$(CCACHE) $(TARGET_CC)" \
	CXX="$(CCACHE) $(TARGET_CXX)" \
	CPP="$(TARGET_CPP)" \
	RANLIB="$(TARGET_RANLIB)" \
	STRIP="$(TARGET_STRIP)" \
	OBJCOPY="$(TARGET_OBJCOPY)" \
	OBJDUMP="$(TARGET_OBJDUMP)" \
	INSTALL="$(__autotools-install-bin) -p" \
	MANIFEST_TOOL=":" \
	CC_FOR_BUILD="$(HOST_CC)" \
	CPPFLAGS="$(TARGET_AUTOTOOLS_CPPFLAGS)" \
	CFLAGS="$(TARGET_AUTOTOOLS_CFLAGS)" \
	CXXFLAGS="$(TARGET_AUTOTOOLS_CXXFLAGS)" \
	LDFLAGS="$(TARGET_AUTOTOOLS_LDFLAGS)" \
	DYN_LDFLAGS="$(TARGET_AUTOTOOLS_DYN_LDFLAGS)" \
	BISON_PATH="$(BISON_PATH)" \
	XDG_DATA_DIRS=$(TARGET_XDG_DATA_DIRS) \
	$(TARGET_PKG_CONFIG_ENV)

ifeq ("$(TARGET_OS)","mingw32")
  TARGET_AUTOTOOLS_CONFIGURE_ENV += \
      WINDRES="$(TARGET_CROSS)windres" \
      RC="$(TARGET_CROSS)windres"
endif

TARGET_AUTOTOOLS_CONFIGURE_ARGS :=

# Build/target triplet, nothing to do for native build TARGET_ARCH = HOST_ARCH
# For all other, force cross-compilation
# Autotools 'host' is the name of the machine on which the package will run
# and  we call it 'target'.
ifeq ("$(TARGET_OS_FLAVOUR)-$(TARGET_ARCH)","native-$(HOST_ARCH)")
  # Nothing to do let autotools in native mode
else
  ifndef GNU_BUILD_NAME
    GNU_BUILD_NAME := $(shell $(HOST_CC) -dumpmachine)
  endif
  ifndef GNU_TARGET_NAME
    GNU_TARGET_NAME := $(TOOLCHAIN_TARGET_NAME)
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

# For cross-compilation, use /usr as prefix and install in our staging dir
# For native compilation, use staging as prefix and nothing for install dest dir
ifeq ("$(TARGET_OS_FLAVOUR)","native")
  ifndef TARGET_DEPLOY_ROOT
    TARGET_AUTOTOOLS_CONFIGURE_PREFIX := $(TARGET_OUT_STAGING)/usr
    TARGET_AUTOTOOLS_CONFIGURE_SYSCONFDIR := $(TARGET_OUT_STAGING)/etc
    TARGET_AUTOTOOLS_CONFIGURE_BINDIR := $(TARGET_OUT_STAGING)/$(TARGET_DEFAULT_BIN_DESTDIR)
    TARGET_AUTOTOOLS_CONFIGURE_LIBDIR := $(TARGET_OUT_STAGING)/$(TARGET_DEFAULT_LIB_DESTDIR)
    TARGET_AUTOTOOLS_INSTALL_DESTDIR :=
  else
    __deploy-root := $(call remove-trailing-slash,$(TARGET_DEPLOY_ROOT))
    TARGET_AUTOTOOLS_CONFIGURE_PREFIX := $(__deploy-root)/usr
    TARGET_AUTOTOOLS_CONFIGURE_SYSCONFDIR := $(__deploy-root)/etc
    TARGET_AUTOTOOLS_CONFIGURE_BINDIR := $(__deploy-root)/$(TARGET_DEFAULT_BIN_DESTDIR)
    TARGET_AUTOTOOLS_CONFIGURE_LIBDIR := $(__deploy-root)/$(TARGET_DEFAULT_LIB_DESTDIR)
    ifneq ("$(call str-starts-with,$(TARGET_DEPLOY_ROOT),$(TARGET_OUT_STAGING))","")
      TARGET_AUTOTOOLS_INSTALL_DESTDIR :=
    else
      TARGET_AUTOTOOLS_INSTALL_DESTDIR := $(TARGET_OUT_STAGING)
    endif
  endif
else
  TARGET_AUTOTOOLS_CONFIGURE_PREFIX := /usr
  TARGET_AUTOTOOLS_CONFIGURE_SYSCONFDIR := /etc
  TARGET_AUTOTOOLS_CONFIGURE_BINDIR := /$(TARGET_DEFAULT_BIN_DESTDIR)
  TARGET_AUTOTOOLS_CONFIGURE_LIBDIR := /$(TARGET_DEFAULT_LIB_DESTDIR)
  TARGET_AUTOTOOLS_INSTALL_DESTDIR := $(TARGET_OUT_STAGING)
endif

TARGET_AUTOTOOLS_CONFIGURE_ARGS += \
	--prefix="$(TARGET_AUTOTOOLS_CONFIGURE_PREFIX)" \
	--sysconfdir="$(TARGET_AUTOTOOLS_CONFIGURE_SYSCONFDIR)" \
	ac_cv_prog_YACC=$(BISON_PATH)

ifneq ("$(TARGET_DEFAULT_BIN_DESTDIR)","usr/bin")
TARGET_AUTOTOOLS_CONFIGURE_ARGS += \
	--bindir="$(TARGET_AUTOTOOLS_CONFIGURE_BINDIR)"
endif

ifneq ("$(TARGET_DEFAULT_LIB_DESTDIR)","usr/lib")
TARGET_AUTOTOOLS_CONFIGURE_ARGS += \
	--libdir="$(TARGET_AUTOTOOLS_CONFIGURE_LIBDIR)"
endif

# Finally, add common arguments
TARGET_AUTOTOOLS_CONFIGURE_ARGS += \
	$(__autotools-configure-args)

# Environment to use when executing make
# Use PKG_CONFIG_ENV in case a package needs automatic reconfiguration
TARGET_AUTOTOOLS_MAKE_ENV := \
	PATH="$(__autotools-host-path)" \
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

$(__autotools-target-cache-file): $(BUILD_SYSTEM)/autotools-cache/configure
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

autotools-target-cache-file-clean:
	@rm -f $(__autotools-target-cache-file)

clobber: autotools-target-cache-file-clean

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
