###############################################################################
## @file cmake-setup.mk
## @author Y.M. Morgan
## @date 2013/07/24
###############################################################################

###############################################################################
## Variables used for cmake.
###############################################################################

CMAKE := $(shell which cmake)

CMAKE_TOOLCHAIN_FILE := $(TARGET_OUT_BUILD)/toolchainfile.cmake

CMAKE_ASM_FLAGS := \
	$(TARGET_GLOBAL_ASFLAGS)

CMAKE_C_FLAGS := \
	$(call normalize-system-c-includes,$(TARGET_GLOBAL_C_INCLUDES)) \
	$(TARGET_GLOBAL_CFLAGS)

CMAKE_CXX_FLAGS := \
	$(filter-out -std=%,$(CMAKE_C_FLAGS)) \
	$(TARGET_GLOBAL_CXXFLAGS)

CMAKE_EXE_LINKER_FLAGS := \
	$(TARGET_GLOBAL_LDFLAGS) $(TARGET_GLOBAL_LDLIBS)

CMAKE_SHARED_LINKER_FLAGS := \
	$(TARGET_GLOBAL_LDFLAGS_SHARED) $(TARGET_GLOBAL_LDLIBS_SHARED)

CMAKE_MODULE_LINKER_FLAGS := \
	$(TARGET_GLOBAL_LDFLAGS_SHARED) $(TARGET_GLOBAL_LDLIBS_SHARED)

CMAKE_CONFIGURE_ARGS := \
	-DCMAKE_INSTALL_PREFIX="$(TARGET_AUTOTOOLS_CONFIGURE_PREFIX)" \

CMAKE_MAKE_ARGS := \
	DESTDIR="$(TARGET_AUTOTOOLS_INSTALL_DESTDIR)"

# Force static compilation if required
ifeq ("$(TARGET_FORCE_STATIC)","1")
  CMAKE_CONFIGURE_ARGS += -DBUILD_SHARED_LIBS=OFF
endif

# Quiet/Verbose flags
ifeq ("$(V)","0")
  CMAKE_MAKE_ARGS += -s --no-print-directory
else
  CMAKE_MAKE_ARGS += VERBOSE=1
endif

###############################################################################
## Generation of toolchain file.
###############################################################################

ifeq ("$(TARGET_OS_FLAVOUR)","native")
  CMAKE_SEARCH_OPTION += BOTH
else
  CMAKE_SEARCH_OPTION += ONLY
endif

__target_cmake_root_path :=
$(foreach __dir,$(TARGET_OUT_STAGING) $(TARGET_SDK_DIRS), \
	$(eval __target_cmake_root_path := $(__target_cmake_root_path) \"$(__dir)\") \
)

define cmake-gen-toolchain-file
	echo "set(CMAKE_SYSTEM_NAME Linux)"; \
	echo "set(CMAKE_SYSTEM_PROCESSOR \"$(TARGET_ARCH)\")"; \
	echo "set(CMAKE_C_COMPILER \"$(TARGET_CC)\")"; \
	echo "set(CMAKE_CXX_COMPILER \"$(TARGET_CXX)\")"; \
	echo "set(CMAKE_AR \"$(TARGET_AR)\" CACHE FILEPATH "Archiver")"; \
	echo "set(CMAKE_LINKER \"$(TARGET_LD)\")"; \
	echo 'set(CMAKE_ASM_FLAGS \
		"$(subst \,\\\,$(CMAKE_AS_FLAGS)) $${ALCHEMY_EXTRA_AS_FLAGS}" \
		CACHE STRING "ASM_FLAGS")'; \
	echo 'set(CMAKE_C_FLAGS \
		"$(subst \,\\\,$(CMAKE_C_FLAGS)) $${ALCHEMY_EXTRA_C_FLAGS}" \
		CACHE STRING "C_FLAGS")'; \
	echo 'set(CMAKE_CXX_FLAGS \
		"$(subst \,\\\,$(CMAKE_CXX_FLAGS)) $${ALCHEMY_EXTRA_CXX_FLAGS}" \
		CACHE STRING "CXX_FLAGS")'; \
	echo "set(CMAKE_EXE_LINKER_FLAGS \
		\"$(CMAKE_EXE_LINKER_FLAGS) \$${ALCHEMY_EXTRA_EXE_LINKER_FLAGS}\" \
		CACHE STRING \"EXE_LINKER_FLAGS\")"; \
	echo "set(CMAKE_SHARED_LINKER_FLAGS \
		\"$(CMAKE_SHARED_LINKER_FLAGS) \$${ALCHEMY_EXTRA_SHARED_LINKER_FLAGS}\" \
		CACHE STRING \"SHARED_LINKER_FLAGS\")"; \
	echo "set(CMAKE_MODULE_LINKER_FLAGS \
		\"$(CMAKE_MODULE_LINKER_FLAGS) \$${ALCHEMY_EXTRA_MODULE_LINKER_FLAGS}\" \
		CACHE STRING \"MODULE_LINKER_FLAGS\")"; \
	echo "set(CMAKE_INSTALL_SO_NO_EXE 0)"; \
	echo "set(CMAKE_FIND_ROOT_PATH $(__target_cmake_root_path))"; \
	echo "set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)"; \
	echo "set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY $(CMAKE_SEARCH_OPTION))"; \
	echo "set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE $(CMAKE_SEARCH_OPTION))"; \
	echo "set(CMAKE_COLOR_MAKEFILE OFF CACHE BOOL \"COLOR_MAKEFILE\")"; \
	echo "set(CMAKE_SKIP_INSTALL_RPATH ON CACHE BOOL \"SKIP_INSTALL_RPATH\")"; \
	echo "set(CMAKE_LIBRARY_ARCHITECTURE $(TOOLCHAIN_TARGET_NAME))";
endef


# Regenerate the toolchain file if toolchain setup makefiles are updated
$(CMAKE_TOOLCHAIN_FILE): $(BUILD_SYSTEM)/cmake-setup.mk
$(CMAKE_TOOLCHAIN_FILE): $(BUILD_SYSTEM)/toolchains/*.mk
$(CMAKE_TOOLCHAIN_FILE): $(BUILD_SYSTEM)/toolchains/*/*.mk

$(CMAKE_TOOLCHAIN_FILE):
	@mkdir -p $(dir $@)
	@($(cmake-gen-toolchain-file)) > $@

.PHONY: cmake-toolchain-file-clean
cmake-toolchain-file-clean:
	$(Q) rm -f $(CMAKE_TOOLCHAIN_FILE)

clobber: cmake-toolchain-file-clean
