###############################################################################
## @file classes/PYTHON_PACKAGE/rules.mk
## @author Y.M. Morgan
## @date 2019/01/11
##
## Rules for PYTHON_PACKAGE modules.
###############################################################################

# Python executable to use
ifeq ("$(TARGET_OS)-$(TARGET_OS_FLAVOUR)","$(HOST_OS)-native")
  # For native build, assume that a package has installed some links
  _python-pkg-python-bin = $(HOST_OUT_STAGING)/$(HOST_DEFAULT_BIN_DESTDIR)/python
  _python-pkg-python-final-bin = $(HOST_OUT_STAGING)/$(HOST_DEFAULT_BIN_DESTDIR)/python
  _python-pkg-use-native-python := $(true)
else ifneq ("$(call is-module-in-build-config,python3)","")
  _python-pkg-python-bin := $(HOST_OUT_STAGING)/$(HOST_DEFAULT_BIN_DESTDIR)/python3
ifeq ("$(TARGET_OS_FLAVOUR)","native-chroot")
  _python-pkg-python-final-bin = /usr/bin/python3
else
  _python-pkg-python-final-bin = $(HOST_OUT_STAGING)/$(HOST_DEFAULT_BIN_DESTDIR)/python3
endif
  _python-pkg-use-native-python := $(false)
else
  _python-pkg-python-bin :=
  _python-pkg-python-final-bin =
  _python-pkg-use-native-python :=
endif

ifeq ("$(_python-pkg-python-bin)","")
  $(error $(LOCAL_MODULE): python not found)
endif

_module_msg := $(if $(_mode_host),Host )PythonPkg

_module_def_cmd_build := _python-pkg-def-cmd-build
_module_def_cmd_install := _python-pkg-def-cmd-install
_module_def_cmd_clean := _python-pkg-def-cmd-clean

# Determine environment and arguments for build/install
ifneq ("$(_python-pkg-use-native-python)","")

# Using native python host (and its installed packages)

_python-pkg-build-args :=

ifeq ("$(_mode_host)","")
  _python-pkg-env := $(TARGET_AUTOTOOLS_CONFIGURE_ENV) \
     DEB_PYTHON_INSTALL_LAYOUT='deb'
  _python-pkg-install-args := --prefix="$(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR)"
else
  _python-pkg-env := $(HOST_AUTOTOOLS_CONFIGURE_ENV) \
     DEB_PYTHON_INSTALL_LAYOUT='deb'
  _python-pkg-install-args := --prefix="$(HOST_OUT_STAGING)/$(HOST_ROOT_DESTDIR)"
endif

_python-pkg-need-pythonpath := $(call not,$(_mode_host))
_python-pkg-need-sysconfigdata := $(false)

ifeq ("$(LOCAL_PYTHONPKG_TYPE)","setuptools")
  _python-pkg-install-args += --single-version-externally-managed
  _python-pkg-install-args += --root=/
endif

else ifeq ("$(_mode_host)","")

# Using compiled python for target

_python-pkg-env := \
	$(TARGET_AUTOTOOLS_CONFIGURE_ENV) \
	PYTHONNOUSERSITE=1 \
	SETUPTOOLS_USE_DISTUTILS=stdlib \
	DEB_PYTHON_INSTALL_LAYOUT='deb' \
	_python_sysroot="$(TARGET_OUT_STAGING)" \
	_python_prefix="/$(TARGET_ROOT_DESTDIR)" \
	_python_exec_prefix="/$(TARGET_ROOT_DESTDIR)"

_python-pkg-build-args := \
	--executable="$(_python-pkg-python-final-bin)"

_python-pkg-install-args := \
	--prefix="$(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR)" \

_python-pkg-need-pythonpath := $(true)
_python-pkg-need-sysconfigdata := $(true)

ifeq ("$(LOCAL_PYTHONPKG_TYPE)","setuptools")
  _python-pkg-install-args += --single-version-externally-managed
  _python-pkg-install-args += --root=/
endif

else

# Using compiled python to build for host

_python-pkg-env := \
	$(HOST_AUTOTOOLS_CONFIGURE_ENV) \
	PYTHONNOUSERSITE=1 \
	SETUPTOOLS_USE_DISTUTILS=stdlib

_python-pkg-build-args := \

_python-pkg-install-args := \
	--prefix="$(HOST_OUT_STAGING)/$(HOST_ROOT_DESTDIR)"

_python-pkg-need-pythonpath := $(false)
_python-pkg-need-sysconfigdata := $(false)

endif

# Add flags in environment
ifneq ("$(strip $(_external_add_CFLAGS))","")
  _python-pkg-env += ASFLAGS="$$ASFLAGS $(_external_add_ASFLAGS)"
endif

ifneq ("$(strip $(_external_add_CFLAGS))","")
  _python-pkg-env += CFLAGS="$$CFLAGS $(_external_add_CFLAGS)"
endif

ifneq ("$(strip $(_external_add_CXXFLAGS))","")
  _python-pkg-env += CXXFLAGS="$$CXXFLAGS $(_external_add_CXXFLAGS)"
endif

ifneq ("$(strip $(_external_add_LDFLAGS))","")
  _python-pkg-env += LDFLAGS="$$LDFLAGS $(_external_add_LDFLAGS)"
endif

# Remove -Wl,--unresolved-symbols=ignore-in-shared-libs from LDFLAGS found in env
# Under linux, python extensions .so do not link anymore with -lpython as they
# assume all symbols will be found in the main executable
# The flag may be included in TARGET_GLOBAL_LDFLAGS in some configuration, so
# remove them here
_python-pkg-remove-ldflags := -Wl,--unresolved-symbols=ignore-in-shared-libs
_python-pkg-env := $(filter-out $(_python-pkg-remove-ldflags),$(_python-pkg-env))

include $(BUILD_SYSTEM)/classes/GENERIC/rules.mk

# Build in a custom directory
_python-pkg-build-args += --build-base="$(_generic_obj_dir)"

$(LOCAL_TARGETS): PRIVATE_PYTHON := $(_python-pkg-python-bin)
$(LOCAL_TARGETS): PRIVATE_SETUP_PY := $(LOCAL_PYTHONPKG_SETUP_PY)
$(LOCAL_TARGETS): PRIVATE_ENV := $(_python-pkg-env) $(LOCAL_PYTHONPKG_ENV)
$(LOCAL_TARGETS): PRIVATE_BUILD_ARGS := $(_python-pkg-build-args) $(LOCAL_PYTHONPKG_BUILD_ARGS)
$(LOCAL_TARGETS): PRIVATE_INSTALL_ARGS := $(_python-pkg-install-args) $(LOCAL_PYTHONPKG_INSTALL_ARGS)
$(LOCAL_TARGETS): PRIVATE_NEED_PYTHONPATH := $(_python-pkg-need-pythonpath)
$(LOCAL_TARGETS): PRIVATE_NEED_SYSCONFIGDATA := $(_python-pkg-need-sysconfigdata)
