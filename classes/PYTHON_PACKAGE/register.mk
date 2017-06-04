###############################################################################
## @file classes/PYTHON_PACKAGE/register.mk
## @author Y.M. Morgan
## @date 2019/01/A1
##
## Register PYTHON_PACKAGE modules.
###############################################################################

# Set also LOCAL_MODULE so that everything works correctly
ifneq ("$(LOCAL_HOST_MODULE)","")
  LOCAL_MODULE := $(LOCAL_HOST_MODULE)
endif

LOCAL_MODULE_CLASS := PYTHON_PACKAGE

LOCAL_MODULE_FILENAME := $(LOCAL_MODULE).done
LOCAL_DONE_FILES += $(LOCAL_MODULE).done

ifneq ("$(filter %$(LOCAL_PYTHONPKG_TYPE),distutils setuptools)","$(LOCAL_PYTHONPKG_TYPE)")
  $(error $(LOCAL_PATH): Invalid or missing LOCAL_PYTHONPKG_TYPE: '$(LOCAL_PYTHONPKG_TYPE)')
endif

ifeq ("$(LOCAL_PYTHONPKG_SETUP_PY)","")
  LOCAL_PYTHONPKG_SETUP_PY := setup.py
endif

# Add python dependencies
ifneq ("$(LOCAL_HOST_MODULE)","")
  LOCAL_DEPENDS_MODULES += host.python
  ifeq ("$(LOCAL_PYTHONPKG_TYPE)","setuptools")
    LOCAL_DEPENDS_MODULES += host.python-setuptools
  endif
else
  LOCAL_DEPENDS_HOST_MODULES += host.python
  ifeq ("$(LOCAL_PYTHONPKG_TYPE)","setuptools")
    LOCAL_DEPENDS_HOST_MODULES += host.python-setuptools
  endif
  LOCAL_DEPENDS_MODULES += python
endif

# Register in the system
$(module-add)
