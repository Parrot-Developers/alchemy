###############################################################################
## @file classes/CMAKE/setup.mk
## @author Y.M. Morgan
## @date 2013/07/24
##
## Setup CMAKE modules.
###############################################################################

###############################################################################
## Setup some internal stuff.
###############################################################################

define _cmake-def-cmd-configure
	@mkdir -p $(PRIVATE_OBJ_DIR)
	$(Q) cd $(PRIVATE_OBJ_DIR) && rm -f CMakeCache.txt && \
		$(PKG_CONFIG_ENV) $(CMAKE) \
			-DCMAKE_TOOLCHAIN_FILE="$($(PRIVATE_MODE)_CMAKE_TOOLCHAIN_FILE)" \
			$($(PRIVATE_MODE)_CMAKE_CONFIGURE_ARGS) $(PRIVATE_CONFIGURE_ARGS) \
			$(PRIVATE_SRC_DIR)
endef

define _cmake-def-cmd-build
	$(Q) $(MAKE) -C $(PRIVATE_OBJ_DIR) \
		$($(PRIVATE_MODE)_CMAKE_MAKE_ARGS) $(PRIVATE_MAKE_BUILD_ARGS)
endef

define _cmake-def-cmd-install
	$(Q) $(MAKE) -C $(PRIVATE_OBJ_DIR) \
		$($(PRIVATE_MODE)_CMAKE_MAKE_ARGS) $(PRIVATE_MAKE_INSTALL_ARGS) install/fast
endef

# Force success for command in case "uninstall" or "clean" is not supported
# or Makefile not present
define _cmake-def-cmd-clean
	$(Q) if [ -f $(PRIVATE_OBJ_DIR)/Makefile ]; then \
		$(MAKE) --keep-going --ignore-errors -C $(PRIVATE_OBJ_DIR) \
			$($(PRIVATE_MODE)_CMAKE_MAKE_ARGS) $(PRIVATE_MAKE_INSTALL_ARGS) \
			uninstall || echo "Ignoring uninstall errors"; \
		$(MAKE) --keep-going --ignore-errors -C $(PRIVATE_OBJ_DIR) \
			$($(PRIVATE_MODE)_CMAKE_MAKE_ARGS) \
			clean || echo "Ignoring clean errors"; \
	fi;
endef

###############################################################################
## Variables used for cmake.
###############################################################################

ifndef CMAKE
  CMAKE := $(shell which cmake 2>/dev/null)
endif

ifeq ("$(TARGET_OS)","linux")
  TARGET_CMAKE_SYSTEM_NAME := Linux
else ifeq ("$(TARGET_OS)","darwin")
  TARGET_CMAKE_SYSTEM_NAME := Darwin
else ifeq ("$(TARGET_OS)","windows")
  TARGET_CMAKE_SYSTEM_NAME := Windows
else
  TARGET_CMAKE_SYSTEM_NAME := $(TARGET_OS)
endif

ifeq ("$(TARGET_ARCH)","x64")
  TARGET_CMAKE_SYSTEM_PROCESSOR := "x86_64"
else
  TARGET_CMAKE_SYSTEM_PROCESSOR := $(TARGET_ARCH)
endif


TARGET_CMAKE_TOOLCHAIN_FILE := $(TARGET_OUT_BUILD)/toolchainfile.cmake

TARGET_CMAKE_ASM_FLAGS := \
	$(TARGET_GLOBAL_ASFLAGS)

TARGET_CMAKE_C_FLAGS := \
	$(call normalize-system-c-includes,$(TARGET_GLOBAL_C_INCLUDES),TARGET) \
	$(TARGET_GLOBAL_CFLAGS)

TARGET_CMAKE_CXX_FLAGS := \
	$(filter-out -std=%,$(TARGET_CMAKE_C_FLAGS)) \
	$(TARGET_GLOBAL_CXXFLAGS)

TARGET_CMAKE_EXE_LINKER_FLAGS := \
	$(TARGET_GLOBAL_LDFLAGS) $(TARGET_GLOBAL_LDLIBS)

TARGET_CMAKE_SHARED_LINKER_FLAGS := \
	$(TARGET_GLOBAL_LDFLAGS) $(TARGET_GLOBAL_LDLIBS)

TARGET_CMAKE_MODULE_LINKER_FLAGS := \
	$(TARGET_GLOBAL_LDFLAGS) $(TARGET_GLOBAL_LDLIBS)

TARGET_CMAKE_CONFIGURE_ARGS := \
	-DCMAKE_INSTALL_PREFIX="$(TARGET_AUTOTOOLS_CONFIGURE_PREFIX)"

TARGET_CMAKE_MAKE_ARGS := \
	DESTDIR="$(TARGET_AUTOTOOLS_INSTALL_DESTDIR)"

# Force static compilation if required
ifeq ("$(TARGET_FORCE_STATIC)","1")
  TARGET_CMAKE_CONFIGURE_ARGS += -DBUILD_SHARED_LIBS=OFF
else
  TARGET_CMAKE_CONFIGURE_ARGS += -DBUILD_SHARED_LIBS=ON
endif

# Quiet/Verbose flags
ifeq ("$(V)","0")
  TARGET_CMAKE_MAKE_ARGS += -s --no-print-directory
else
  TARGET_CMAKE_MAKE_ARGS += VERBOSE=1
endif

# On windows host, force generation of Unix makefiles instead of Visual Studio projects
ifeq ("$(HOST_OS)","windows")
  TARGET_CMAKE_CONFIGURE_ARGS += -G "Unix Makefiles"
endif

# On yocto, the CC and CXX can contains arguments which is invalid for toolchain
# files: we split the command and move arguments to C_FLAGS / CXX_FLAGS
ifeq ("$(TARGET_OS_FLAVOUR)","yocto")
  TARGET_CMAKE_CC := $(call first,$(TARGET_CC))
  TARGET_CMAKE_C_FLAGS := $(call rest,$(TARGET_CC)) $(TARGET_CMAKE_C_FLAGS)
  TARGET_CMAKE_CXX := $(call first,$(TARGET_CXX))
  TARGET_CMAKE_CXX_FLAGS := $(call rest,$(TARGET_CXX)) $(TARGET_CMAKE_CXX_FLAGS)
else
  TARGET_CMAKE_CC := $(TARGET_CC)
  TARGET_CMAKE_CXX := $(TARGET_CXX)
endif

###############################################################################
## Generation of toolchain file.
###############################################################################

ifeq ("$(TARGET_OS_FLAVOUR)","native")
  TARGET_CMAKE_SEARCH_OPTION += BOTH
else
  TARGET_CMAKE_SEARCH_OPTION += ONLY
endif

ifndef TARGET_CMAKE_ROOT_PATH
  TARGET_CMAKE_ROOT_PATH :=
endif
$(foreach __dir,$(TARGET_OUT_STAGING) $(TARGET_SDK_DIRS), \
	$(eval TARGET_CMAKE_ROOT_PATH := $(TARGET_CMAKE_ROOT_PATH) \"$(__dir)\") \
)

define _cmake-target-gen-toolchain-file
	echo "set(CMAKE_SYSTEM_NAME $(TARGET_CMAKE_SYSTEM_NAME))"; \
	echo "set(CMAKE_SYSTEM_PROCESSOR \"$(TARGET_CMAKE_SYSTEM_PROCESSOR)\")"; \
	echo "set(CMAKE_C_COMPILER_LAUNCHER \"$(CCACHE)\")"; \
	echo "set(CMAKE_C_COMPILER \"$(TARGET_CMAKE_CC)\")"; \
	echo "set(CMAKE_CXX_COMPILER_LAUNCHER \"$(CCACHE)\")"; \
	echo "set(CMAKE_CXX_COMPILER \"$(TARGET_CMAKE_CXX)\")"; \
	echo "set(CMAKE_AR \"$(TARGET_AR)\" CACHE FILEPATH "Archiver")"; \
	echo "set(CMAKE_LINKER \"$(TARGET_LD)\")"; \
	echo 'set(CMAKE_ASM_FLAGS \
		"$(subst \,\\\,$(TARGET_CMAKE_ASM_FLAGS)) $${ALCHEMY_EXTRA_ASM_FLAGS}" \
		CACHE STRING "ASM_FLAGS")'; \
	echo 'set(CMAKE_C_FLAGS \
		"$(subst \,\\\,$(TARGET_CMAKE_C_FLAGS)) $${ALCHEMY_EXTRA_C_FLAGS}" \
		CACHE STRING "C_FLAGS")'; \
	echo 'set(CMAKE_CXX_FLAGS \
		"$(subst \,\\\,$(TARGET_CMAKE_CXX_FLAGS)) $${ALCHEMY_EXTRA_CXX_FLAGS}" \
		CACHE STRING "CXX_FLAGS")'; \
	echo "set(CMAKE_EXE_LINKER_FLAGS \
		\"$(TARGET_CMAKE_EXE_LINKER_FLAGS) \$${ALCHEMY_EXTRA_EXE_LINKER_FLAGS}\" \
		CACHE STRING \"EXE_LINKER_FLAGS\")"; \
	echo "set(CMAKE_SHARED_LINKER_FLAGS \
		\"$(TARGET_CMAKE_SHARED_LINKER_FLAGS) \$${ALCHEMY_EXTRA_SHARED_LINKER_FLAGS}\" \
		CACHE STRING \"SHARED_LINKER_FLAGS\")"; \
	echo "set(CMAKE_MODULE_LINKER_FLAGS \
		\"$(TARGET_CMAKE_MODULE_LINKER_FLAGS) \$${ALCHEMY_EXTRA_MODULE_LINKER_FLAGS}\" \
		CACHE STRING \"MODULE_LINKER_FLAGS\")"; \
	echo "set(CMAKE_INSTALL_SO_NO_EXE 0)"; \
	echo "set(CMAKE_FIND_ROOT_PATH $(TARGET_CMAKE_ROOT_PATH))"; \
	echo "set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)"; \
	echo "set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY $(TARGET_CMAKE_SEARCH_OPTION))"; \
	echo "set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE $(TARGET_CMAKE_SEARCH_OPTION))"; \
	echo "set(CMAKE_COLOR_MAKEFILE OFF CACHE BOOL \"COLOR_MAKEFILE\")"; \
	echo "set(CMAKE_SKIP_INSTALL_RPATH ON CACHE BOOL \"SKIP_INSTALL_RPATH\")"; \
	echo "set(CMAKE_LIBRARY_ARCHITECTURE $(TARGET_TOOLCHAIN_TRIPLET))";
endef

define _cmake-target-gen-toolchain-file-macos
	echo "set(CMAKE_OSX_ARCHITECTURES $(filter-out -arch,$(APPLE_ARCH)))"; \
	echo "set(CMAKE_OSX_DEPLOYMENT_TARGET $(TARGET_MACOS_VERSION))"; \
	echo "set(CMAKE_OSX_SYSROOT $(shell xcrun --sdk $(APPLE_SDK) --show-sdk-path))";
endef

define _cmake-target-gen-toolchain-file-ios
	echo "set(CMAKE_OSX_ARCHITECTURES $(filter-out -arch,$(APPLE_ARCH)))"; \
	echo "set(CMAKE_OSX_DEPLOYMENT_TARGET $(TARGET_IPHONE_VERSION))"; \
	echo "set(CMAKE_OSX_SYSROOT $(shell xcrun --sdk $(APPLE_SDK) --show-sdk-path))";
endef

# Always execute commands but update the toolchain file only if needed
$(TARGET_CMAKE_TOOLCHAIN_FILE): .FORCE
	@mkdir -p $(dir $@)
	@($(_cmake-target-gen-toolchain-file)) > $@.tmp
ifeq ("$(TARGET_OS)","darwin")
ifeq ("$(APPLE_SDK)","macosx")
	@($(_cmake-target-gen-toolchain-file-macos)) >> $@.tmp
else
	@($(_cmake-target-gen-toolchain-file-ios)) >> $@.tmp
endif
endif
	$(call update-file-if-needed,$@,$@.tmp)

.PHONY: _cmake-target-toolchain-file-clean
_cmake-target-cmake-toolchain-file-clean:
	$(Q) rm -f $(TARGET_CMAKE_TOOLCHAIN_FILE)

clobber: _cmake-target-toolchain-file-clean
