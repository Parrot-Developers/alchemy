###############################################################################
## @file classes/PYTHON_EXTENSION/rules.mk
## @author Y.M. Morgan
## @date 2016/03/20
##
## Rules for PYTHON_EXTENSION modules.
###############################################################################

# Python executable
ifneq ("$(call is-module-in-build-config,python3)","")
  PYTHON := $(HOST_OUT_STAGING)/$(HOST_DEFAULT_BIN_DESTDIR)/python3
else ifeq ("$(TARGET_OS)-$(TARGET_OS_FLAVOUR)","$(HOST_OS)-native")
  PYTHON = $(shell which python 2>/dev/null)
else
  PYTHON :=
endif

ifeq ("$(PYTHON)","")
  $(error $(LOCAL_MODULE): python not found)
endif

# Location of setup.py
ifneq ("$(LOCAL_ARCHIVE)","")
  setup_py_file := $(_module_build_dir)/$(LOCAL_ARCHIVE_SUBDIR)/setup.py
else
  setup_py_file := $(LOCAL_PATH)/setup.py
endif

# Environment for setup.py
setup_py_env := \
	$(TARGET_AUTOTOOLS_CONFIGURE_ENV) \
	CROSS_COMPILING="yes" \
	PYTHON_MODULES_INCLUDE="$(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR)/include" \
	PYTHON_MODULES_LIB="$(TARGET_OUT_STAGING)/lib $(TARGET_OUT_STAGING)/$(TARGET_DEFAULT_LIB_DESTDIR)" \
	_PYTHON_HOST_PLATFORM="$(TARGET_TOOLCHAIN_TRIPLET)" \
	PYTHONDONTWRITEBYTECODE=y \
	_python_sysroot="$(TARGET_OUT_STAGING)" \
	_python_prefix="/$(TARGET_ROOT_DESTDIR)" \
	_python_exec_prefix="/$(TARGET_ROOT_DESTDIR)"

# File recording list of installed files
install_record_file := $(_module_build_dir)/installed-files.txt

# Build arguments
build_args := \
	--build-base="$(_module_build_dir)" \
	--build-lib="$(_module_build_dir)/lib" \
	--build-scripts="$(_module_build_dir)/script" \
	--build-temp="$(_module_build_dir)/temp" \

# Install arguments
install_args := \
	--prefix="$(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR)" \
	--record="$(install_record_file)"

# Clean arguments
clean_args := \
	--all \
	--build-base="$(_module_build_dir)" \
	--build-lib="$(_module_build_dir)/lib" \
	--build-scripts="$(_module_build_dir)/script" \
	--build-temp="$(_module_build_dir)/temp" \
	--bdist-base="$(_module_build_dir)/bdist"

_module_msg := $(if $(_mode_host),Host )PythonExt

_module_def_cmd_build := _python-ext-def-cmd-build
_module_def_cmd_install := _python-ext-def-cmd-install

include $(BUILD_SYSTEM)/classes/GENERIC/rules.mk

$(LOCAL_TARGETS): PRIVATE_PYTHON := $(PYTHON)
$(LOCAL_TARGETS): PRIVATE_SETUP_PY_FILE := $(setup_py_file)
$(LOCAL_TARGETS): PRIVATE_SETUP_PY_ENV := $(setup_py_env)
$(LOCAL_TARGETS): PRIVATE_INSTALL_RECORD_FILE := $(install_record_file)
$(LOCAL_TARGETS): PRIVATE_BUILD_ARGS := $(build_args)
$(LOCAL_TARGETS): PRIVATE_INSTALL_ARGS := $(install_args)
$(LOCAL_TARGETS): PRIVATE_CLEAN_ARGS := $(clean_args)

$(LOCAL_TARGETS): PRIVATE_EXTRA_SETUP_PY_ENV := $(LOCAL_PYTHONEXT_SETUP_PY_ENV)
$(LOCAL_TARGETS): PRIVATE_EXTRA_SETUP_PY_ARGS := $(LOCAL_PYTHONEXT_SETUP_PY_ARGS)
