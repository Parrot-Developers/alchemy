###############################################################################
## @file classes/QMAKE/setup.mk
## @author F.F. Ferrand
## @date 2015/05/07
##
## Setup QMAKE modules.
###############################################################################

###############################################################################
## Variables used for qmake.
###############################################################################

# Default Qt version
TARGET_QT_VERSION ?= 5.4

# Map TARGET_OS/FLAVOUR to Qt platforms
ifeq ("$(TARGET_OS)-$(TARGET_OS_FLAVOUR)","$(HOST_OS)-native")
  ifeq ("$(TARGET_OS)","darwin")
    TARGET_QT_PLATFORM ?= clang_64
  else ifeq ("$(TARGET_OS)-$(TARGET_ARCH)","linux-x64")
    TARGET_QT_PLATFORM ?= gcc_64
  else ifeq ("$(TARGET_OS)-$(TARGET_ARCH)-$(HOST_ARCH)","linux-x86-x64")
    TARGET_QT_PLATFORM ?= gcc_32
  else ifeq ("$(TARGET_OS)-$(TARGET_ARCH)-$(HOST_ARCH)","linux-x86-x86")
    TARGET_QT_PLATFORM ?= gcc
  else
    TARGET_QT_PLATFORM ?= unknown
  endif
else ifeq ("$(TARGET_OS)","linux")
  ifeq ("$(TARGET_OS_FLAVOUR)-$(TARGET_ARCH)-$(TARGET_CPU)","android-arm-armv7a")
    TARGET_QT_PLATFORM ?= android_armv7
  else ifeq ("$(TARGET_OS_FLAVOUR)-$(TARGET_ARCH)-$(TARGET_CPU)","android-arm-armv7a-neon")
    TARGET_QT_PLATFORM ?= android_armv7
  else ifeq ("$(TARGET_OS_FLAVOUR)-$(TARGET_ARCH)","android-arm")
    TARGET_QT_PLATFORM ?= android_armv5
  else ifeq ("$(TARGET_OS_FLAVOUR)-$(TARGET_ARCH)","android-x86")
    TARGET_QT_PLATFORM ?= android_x86
  else ifeq ("$(TARGET_OS_FLAVOUR)-$(TARGET_ARCH)","native-x64")
    TARGET_QT_PLATFORM ?= linux_64
  else ifeq ("$(TARGET_OS_FLAVOUR)-$(TARGET_ARCH)","native-x86")
    TARGET_QT_PLATFORM ?= linux_32
  else
    TARGET_QT_PLATFORM ?= unknown
  endif
else ifeq ("$(TARGET_OS)","darwin")
  ifeq ("$(TARGET_OS_FLAVOUR)","native")
    TARGET_QT_PLATFORM ?= macos
  else
    TARGET_QT_PLATFORM ?= ios
  endif
else
  TARGET_QT_PLATFORM ?= unknown
endif

# Try to auto-detect Qt SDK path
QT_SDK_DEFAULT_PATHS := \
	/opt/Qt* \
	/opt/QT* \
	/Applications/Qt* \
	~/Qt*

ifndef TARGET_QT_SDKROOT
TARGET_QT_SDKROOT := $(shell shopt -s nullglob ; \
	for path in $(QT_SDK_DEFAULT_PATHS) ; do \
		if [ -e $$path/$(TARGET_QT_VERSION)/$(TARGET_QT_PLATFORM)/bin/qmake ]; then \
			cd $$path && pwd && break; \
		fi; \
	done)
endif

# Define QMake path accordingly
ifndef TARGET_QT_SDK
  ifneq ("$(TARGET_QT_SDKROOT)","")
    TARGET_QT_SDK := $(TARGET_QT_SDKROOT)/$(TARGET_QT_VERSION)/$(TARGET_QT_PLATFORM)
  else
    TARGET_QT_SDK :=
  endif
endif

# Use qmake from PATH in last resort, on host build
ifndef TARGET_QMAKE
  ifdef QTSDK_QMAKE
    # Compatibility
    $(warning Please use TARGET_QMAKE instead of QTSDK_QMAKE)
    TARGET_QMAKE := $(QTSDK_QMAKE)
  else ifneq ("$(TARGET_QT_SDK)","")
    TARGET_QMAKE := $(TARGET_QT_SDK)/bin/qmake
  else ifeq ("$(TARGET_OS)-$(TARGET_OS_FLAVOUR)","$(HOST_OS)-native")
    TARGET_QMAKE := $(shell which qmake 2>/dev/null)
  else
    TARGET_QMAKE :=
  endif
endif

TARGET_QMAKE_ENV :=
TARGET_QMAKE_ARG :=
TARGET_QMAKE_MAKE_ARG :=

# Silence...
ifeq ("$(V)","0")
  TARGET_QMAKE_ARG += CONFIG+=silent
  TARGET_QMAKE_MAKE_ARG += --no-print-directory
endif

# Export android NDK, SDK path and API level
ifeq ("$(TARGET_OS_FLAVOUR)","android")
TARGET_QMAKE_ENV += ANDROID_NDK_ROOT=$(TARGET_ANDROID_NDK) \
	ANDROID_HOME=$(TARGET_ANDROID_SDK) \
	ANDROID_SDK_ROOT=$(TARGET_ANDROID_SDK) \
	ANDROID_NDK_PLATFORM=android-$(TARGET_ANDROID_MINAPILEVEL) \
	ANDROID_NDK_TOOLCHAIN_VERSION=$(TARGET_CC_VERSION:.x=)
endif

# Need to remove some flags which conflict with flags set by qmake
TARGET_QMAKE_CFLAGS := $(filter-out -miphoneos-version-min=%,$(TARGET_GLOBAL_CFLAGS))
TARGET_QMAKE_LDFLAGS := $(filter-out -miphoneos-version-min=%,$(TARGET_GLOBAL_LDFLAGS))
TARGET_QMAKE_LDFLAGS := $(shell echo $(TARGET_QMAKE_LDFLAGS) | sed 's/-isysroot  *[^ ][^ ]*//g')

###############################################################################
## Generate a .pri file to be included by the .pro file with dependencies found by alchemy
###############################################################################

define _internal-qmake-gen-deps-darwin
	@rm -f $(PRIVATE_ALCHEMY_PRI_FILE)
	@mkdir -p $(dir $(PRIVATE_ALCHEMY_PRI_FILE))
	@( \
		echo "equals(TEMPLATE, lib) {"; \
		echo "    target.path = $(if $(PRIVATE_HAS_QT_SYSROOT),$(TARGET_OUT_STAGING))/$(TARGET_DEFAULT_LIB_DESTDIR)"; \
		$(if $(call streq,$(TARGET_FORCE_STATIC),1),echo "    CONFIG += staticlib";) \
		echo "} else {"; \
		echo "    target.path = $(if $(PRIVATE_HAS_QT_SYSROOT),$(TARGET_OUT_STAGING))/$(TARGET_DEFAULT_BIN_DESTDIR)"; \
		echo "}"; \
		echo "INSTALLS += target"; \
		echo "INCLUDEPATH += $(PRIVATE_C_INCLUDES) $(TARGET_GLOBAL_C_INCLUDES)"; \
		echo "DEPENDPATH += $(PRIVATE_C_INCLUDES) $(TARGET_GLOBAL_C_INCLUDES)"; \
		echo "QMAKE_CFLAGS += $(TARGET_QMAKE_CFLAGS) $(PRIVATE_CFLAGS)"; \
		echo "QMAKE_CXXFLAGS += $(filter-out -std=%,$(TARGET_QMAKE_CFLAGS))"; \
		echo "QMAKE_CXXFLAGS += $(TARGET_GLOBAL_CXXFLAGS)"; \
		echo "QMAKE_CXXFLAGS += $(filter-out -std=%,$(PRIVATE_CFLAGS))"; \
		echo "QMAKE_CXXFLAGS += $(PRIVATE_CXXFLAGS)"; \
		echo "LIBS += $(subst $(APPLE_ARCH),,$(TARGET_QMAKE_LDFLAGS) $(PRIVATE_LDFLAGS))"; \
		echo "LIBS += $(foreach __lib, $(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES), -force_load $(__lib))"; \
		echo "LIBS += $(PRIVATE_ALL_STATIC_LIBRARIES)"; \
		echo "LIBS += $(PRIVATE_ALL_SHARED_LIBRARIES)"; \
		echo "LIBS += $(PRIVATE_LDLIBS)"; \
		echo "LIBS += $(TARGET_GLOBAL_LDLIBS)"; \
		echo "CONFIG += $(APPLE_SDK)"; \
		echo "macx:QMAKE_LFLAGS_SONAME = -Wl,-install_name,$(TARGET_OUT_STAGING)/$(TARGET_DEFAULT_LIB_DESTDIR)/"; \
		echo "QMAKE_IOS_DEVICE_ARCHS = $(filter-out -arch,$(APPLE_ARCH))"; \
		echo "QMAKE_IOS_SIMULATOR_ARCHS = $(filter-out -arch,$(APPLE_ARCH))"; \
		echo "QMAKE_IOS_DEPLOYMENT_TARGET = $(TARGET_IPHONE_VERSION)"; \
		echo "QMAKE_MACOSX_DEPLOYMENT_TARGET = $(TARGET_MACOS_VERSION)"; \
		echo "deployement.files = $(shell find $(TARGET_OUT_STAGING)/$(TARGET_DEFAULT_LIB_DESTDIR) -maxdepth 1 -name '*.dylib' -type f)"; \
		echo "deployement.path = Contents/Frameworks/"; \
		echo "QMAKE_BUNDLE_DATA += deployement"; \
	) >> $(PRIVATE_ALCHEMY_PRI_FILE)
endef

define _internal-qmake-gen-deps
	@mkdir -p $(dir $(PRIVATE_ALCHEMY_PRI_FILE))
	@( \
		echo "equals(TEMPLATE, lib) {"; \
		echo "    target.path = $(if $(PRIVATE_HAS_QT_SYSROOT),$(TARGET_OUT_STAGING))/$(TARGET_DEFAULT_LIB_DESTDIR)"; \
		$(if $(call streq,$(TARGET_FORCE_STATIC),1),echo "    CONFIG += staticlib";) \
		echo "} else {"; \
		echo "    target.path = $(if $(PRIVATE_HAS_QT_SYSROOT),$(TARGET_OUT_STAGING))/$(TARGET_DEFAULT_BIN_DESTDIR)"; \
		echo "}"; \
		echo "INSTALLS += target"; \
		echo "INCLUDEPATH += $(PRIVATE_C_INCLUDES) $(TARGET_GLOBAL_C_INCLUDES)"; \
		echo "DEPENDPATH += $(PRIVATE_C_INCLUDES) $(TARGET_GLOBAL_C_INCLUDES)"; \
		echo "QMAKE_CFLAGS += $(TARGET_QMAKE_CFLAGS) $(PRIVATE_CFLAGS)"; \
		echo "QMAKE_CXXFLAGS += $(filter-out -std=%,$(TARGET_QMAKE_CFLAGS))"; \
		echo "QMAKE_CXXFLAGS += $(TARGET_GLOBAL_CXXFLAGS)"; \
		echo "QMAKE_CXXFLAGS += $(filter-out -std=%,$(PRIVATE_CFLAGS))"; \
		echo "QMAKE_CXXFLAGS += $(PRIVATE_CXXFLAGS)"; \
		echo "LIBS += $(TARGET_QMAKE_LDFLAGS) $(PRIVATE_LDFLAGS)"; \
		echo "LIBS += -Wl,--whole-archive $(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES) -Wl,--no-whole-archive"; \
		echo "LIBS += $(PRIVATE_ALL_STATIC_LIBRARIES)"; \
		echo "LIBS += $(PRIVATE_ALL_SHARED_LIBRARIES)"; \
		echo "LIBS += $(PRIVATE_LDLIBS)"; \
		echo "LIBS += $(TARGET_GLOBAL_LDLIBS)"; \
		echo "ANDROID_EXTRA_LIBS = $(shell find $(TARGET_OUT_STAGING)/$(TARGET_DEFAULT_LIB_DESTDIR) -maxdepth 1 -name 'lib*.so' -type f)"; \
	) >> $(PRIVATE_ALCHEMY_PRI_FILE).tmp
	$(call update-file-if-needed,$(PRIVATE_ALCHEMY_PRI_FILE),$(PRIVATE_ALCHEMY_PRI_FILE).tmp)
endef

_qmake-gen-deps = $(if $(call streq,$($(PRIVATE_MODE)_OS),darwin), \
	$(call _internal-qmake-gen-deps-darwin,$(PRIVATE_MODE)) \
	, \
	$(call _internal-qmake-gen-deps,$(PRIVATE_MODE)) \
)

###############################################################################
###############################################################################

define _qmake-def-cmd-configure
	$(_qmake-gen-deps)
	$(Q) cd $(PRIVATE_BUILD_DIR) \
		&& $(TARGET_QMAKE_ENV) $(QMAKE) $(TARGET_QMAKE_ARG) \
			$(PRIVATE_QMAKE_CONFIGURE_ARGS) \
			$(if $(call is-path-absolute,$(PRIVATE_QMAKE_PRO_FILE)), \
				$(PRIVATE_QMAKE_PRO_FILE) \
				, \
				$(PRIVATE_PATH)/$(PRIVATE_QMAKE_PRO_FILE) \
			)
endef

define _qmake-def-cmd-build
	$(Q) cd $(PRIVATE_BUILD_DIR) \
		&& $(MAKE) $(TARGET_QMAKE_MAKE_ARG) \
			$(PRIVATE_QMAKE_MAKE_BUILD_ARGS)
endef

# Install in staging directory by specifing INSTALL_ROOT (only for qt4, qt5 already
# knows QT_SYSROOT)
# Force STRIP at dummy to install unstripped binaries (alchemy will do it in
# final stage only)
# macro qt5_la_prl_files_fixup is actually defined in qt5/qtbase/atom.mk
define _qmake-def-cmd-install
	$(Q) cd $(PRIVATE_BUILD_DIR) \
		&& $(MAKE) $(TARGET_QMAKE_MAKE_ARG) \
			$(PRIVATE_QMAKE_MAKE_INSTALL_ARGS) \
			STRIP="true || ls" \
			$(if $(PRIVATE_HAS_QT_SYSROOT),$(empty),INSTALL_ROOT=$(TARGET_OUT_STAGING)) \
			install
	$(if $(call is-var-defined,qt5_la_prl_files_fixup),$(qt5_la_prl_files_fixup))
endef

# If makefile is present, call uninstall and clean targets
define _qmake-def-cmd-clean
	$(Q) if [ -f $(PRIVATE_BUILD_DIR)/Makefile ]; then \
		cd $(PRIVATE_BUILD_DIR); \
		$(MAKE) --keep-going --ignore-errors $(TARGET_QMAKE_MAKE_ARG) \
			$(PRIVATE_QMAKE_MAKE_INSTALL_ARGS) \
			$(if $(PRIVATE_HAS_QT_SYSROOT),$(empty),INSTALL_ROOT=$(TARGET_OUT_STAGING)) \
			uninstall || echo "Ignoring uninstall errors"; \
		$(MAKE) --keep-going --ignore-errors $(TARGET_QMAKE_MAKE_ARG) \
			clean || echo "Ignoring clean errors"; \
	fi
endef
