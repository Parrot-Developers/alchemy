###############################################################################
## @file python-ext-rules.mk
## @author Y.M. Morgan
## @date 2014/08/01
##
## Build a pythn extension module.
###############################################################################

# Python executable
ifneq ("$(call is-module-in-build-config,python3)","")
  python_exe := $(HOST_OUT_STAGING)/usr/bin/python3
else ifeq ("$(TARGET_OS)-$(TARGET_OS_FLAVOUR)","$(HOST_OS)-native")
  python_exe = $(realpath $(shell which python))
else
  python_exe :=
endif

ifeq ("$(python_exe)","")
  $(error $(LOCAL_MODULE): python not found.)
endif

built_file := $(build_dir)/$(LOCAL_MODULE).built

# Location of setup.py
ifneq ("$(LOCAL_ARCHIVE)","")
  setup_py_file := $(unpack_dir)/$(LOCAL_ARCHIVE_SUBDIR)/setup.py
else
  setup_py_file := $(LOCAL_PATH)/setup.py
endif

# Environment for setup.py
setup_py_env := \
	$(TARGET_AUTOTOOLS_CONFIGURE_ENV) \
	CROSS_COMPILING="yes" \
	PYTHON_MODULES_INCLUDE="$(TARGET_OUT_STAGING)/usr/include" \
	PYTHON_MODULES_LIB="$(TARGET_OUT_STAGING)/lib $(TARGET_OUT_STAGING)/usr/lib" \
	_PYTHON_HOST_PLATFORM="$(TOOLCHAIN_TARGET_NAME)" \
	PYTHONDONTWRITEBYTECODE=y \
	_python_sysroot="$(TARGET_OUT_STAGING)" \
	_python_prefix="/usr" \
	_python_exec_prefix="/usr"

# File recording list of installed files
install_record_file := $(build_dir)/installed-files.txt

# Build arguments
build_args := \
	--build-base="$(build_dir)" \
	--build-lib="$(build_dir)/lib" \
	--build-scripts="$(build_dir)/script" \
	--build-temp="$(build_dir)/temp" \

# Install arguments
install_args := \
	--prefix="$(TARGET_OUT_STAGING)/usr" \
	--record="$(install_record_file)"

# Clean arguments
clean_args := \
	--all \
	--build-base="$(build_dir)" \
	--build-lib="$(build_dir)/lib" \
	--build-scripts="$(build_dir)/script" \
	--build-temp="$(build_dir)/temp" \
	--bdist-base="$(build_dir)/bdist"

###############################################################################
## Rules.
###############################################################################

# Make sure all prerequisites files are generated first
# But do NOT force recompilation (order only)
$(built_file): | $(all_prerequisites)

# Restart build if any of dependencies have changed
$(built_file): $(all_depends_build_filename) $(all_link_libs_filenames)

# If the user makefile is changed, restart the build
$(built_file): $(LOCAL_PATH)/$(USER_MAKEFILE_NAME)

# Build and install
$(built_file):
	@mkdir -p $(PRIVATE_BUILD_DIR)
	$(call print-banner2,PythonExt,$(PRIVATE_MODULE),Building)
	$(Q) cd $(dir $(PRIVATE_SETUP_PY_FILE)) && \
		$(PRIVATE_SETUP_PY_ENV) \
		$(PRIVATE_EXTRA_SETUP_PY_ENV) \
		$(PRIVATE_PYTHON_EXE) setup.py \
		build $(PRIVATE_BUILD_ARGS) \
		install $(PRIVATE_INSTALL_ARGS) \
		$(PRIVATE_EXTRA_SETUP_PY_ARGS)
	@touch $@

# Done
$(build_dir)/$(LOCAL_MODULE_FILENAME): $(built_file)
	@mkdir -p $(dir $@)
	@touch $@

# Clean targets additional commands
$(LOCAL_MODULE)-clean:
	$(Q) if [ -f $(PRIVATE_INSTALL_RECORD_FILE) ]; then \
		cat $(PRIVATE_INSTALL_RECORD_FILE) | xargs rm -f; \
		rm -f $(PRIVATE_INSTALL_RECORD_FILE); \
	fi
	$(Q) if [ -f $(PRIVATE_SETUP_PY_FILE) ]; then \
		cd $(dir $(PRIVATE_SETUP_PY_FILE)) && \
			$(PRIVATE_SETUP_PY_ENV) \
			$(PRIVATE_PYTHON_EXE) setup.py \
			clean $(PRIVATE_CLEAN_ARGS) \
			|| echo "Ignoring clean errors"; \
	fi

###############################################################################
## Rule-specific variable definitions.
###############################################################################

# clean targets additional variables
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(built_file)

$(LOCAL_TARGETS): PRIVATE_PYTHON_EXE := $(python_exe)
$(LOCAL_TARGETS): PRIVATE_SETUP_PY_FILE := $(setup_py_file)
$(LOCAL_TARGETS): PRIVATE_SETUP_PY_ENV := $(setup_py_env)
$(LOCAL_TARGETS): PRIVATE_INSTALL_RECORD_FILE := $(install_record_file)
$(LOCAL_TARGETS): PRIVATE_BUILD_ARGS := $(build_args)
$(LOCAL_TARGETS): PRIVATE_INSTALL_ARGS := $(install_args)
$(LOCAL_TARGETS): PRIVATE_CLEAN_ARGS := $(clean_args)

$(LOCAL_TARGETS): PRIVATE_EXTRA_SETUP_PY_ENV := $(LOCAL_PYTHONEXT_SETUP_PY_ENV)
$(LOCAL_TARGETS): PRIVATE_EXTRA_SETUP_PY_ARGS := $(LOCAL_PYTHONEXT_SETUP_PY_ARGS)
