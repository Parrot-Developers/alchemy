
LOCAL_PATH := $(call my-dir)

# Only for native builds. For cross build, use python3 repository.

ifeq ("$(TARGET_OS_FLAVOUR)","native")

# version-less python meta-package to be used for internal alchemy dependencies.
include $(CLEAR_VARS)
LOCAL_HOST_MODULE := python
LOCAL_CATEGORY_PATH := python
LOCAL_DESCRIPTION := Python metapackage to select correct underlying module
LOCAL_LIBRARIES := host.python-native
include $(BUILD_META_PACKAGE)


include $(CLEAR_VARS)
LOCAL_MODULE := python
LOCAL_CATEGORY_PATH := python
LOCAL_DESCRIPTION := Python metapackage to select correct underlying module
LOCAL_LIBRARIES := python-native
include $(BUILD_META_PACKAGE)

# Use the on from the host, but define module so other modules find the dependency
include $(CLEAR_VARS)
LOCAL_HOST_MODULE := python-setuptools
LOCAL_CATEGORY_PATH := python
LOCAL_DESCRIPTION := Python setuptools native package
include $(BUILD_CUSTOM)


# Fake host module just to please internal alchemy dependencies
include $(CLEAR_VARS)
LOCAL_HOST_MODULE := python-native
LOCAL_CATEGORY_PATH := python
LOCAL_DESCRIPTION := Python native package for host build
include $(BUILD_CUSTOM)


include $(CLEAR_VARS)

LOCAL_MODULE := python-native
LOCAL_CATEGORY_PATH := python
LOCAL_DESCRIPTION := Python native package for target build

LOCAL_CONFIG_FILES := Config.in
$(call load-config)

# Get python native binary
ifdef CONFIG_PYTHON_NATIVE_VERSION_3
  PYTHON_NATIVE_BIN := $(shell which python3)
else
  PYTHON_NATIVE_BIN := $(shell which python2)
endif

ifneq ("$(PYTHON_NATIVE_BIN)","")

# Get major.minor version of python
PYTHON_NATIVE_VERSION := $(strip $(shell $(PYTHON_NATIVE_BIN) -c \
	"import sys; print('{0.major:d}.{0.minor:d}'.format(sys.version_info))"))

# Include directories, do not get system headers for virtual env
# Python3 adds an 'm' at the end of the version for include directory
ifndef CONFIG_PYTHON_NATIVE_USE_VIRTUAL_ENV
  LOCAL_EXPORT_C_INCLUDES += $(shell $(PYTHON_NATIVE_BIN)-config --includes)
endif
ifdef CONFIG_PYTHON_NATIVE_VERSION_3
  LOCAL_EXPORT_C_INCLUDES += $(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR)/include/python$(PYTHON_NATIVE_VERSION)m
else
  LOCAL_EXPORT_C_INCLUDES += $(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR)/include/python$(PYTHON_NATIVE_VERSION)
endif


LOCAL_EXPORT_LDLIBS := $(shell $(PYTHON_NATIVE_BIN)-config --ldflags)

endif

# Install virtual env in staging if needed, otherwise simply create links
# Create a simlink with a version-less name in lib directory
define LOCAL_CMD_BUILD
	@if [ -z "$(PYTHON_NATIVE_BIN)" ]; then \
		echo "Missing python binary"; \
		exit 1; \
	fi
	@mkdir -p $(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR)/bin
	@mkdir -p $(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR)/lib/python$(PYTHON_NATIVE_VERSION)
	$(if $(CONFIG_PYTHON_NATIVE_USE_VIRTUAL_ENV), \
		$(Q) virtualenv -p $(PYTHON_NATIVE_BIN) \
			$(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR) \
			--always-copy \
			--system-site-packages \
		, \
		$(Q) ln -sf $(PYTHON_NATIVE_BIN) $(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR)/bin/python \
	)
	$(Q) ln -sf python$(PYTHON_NATIVE_VERSION) $(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR)/lib/python
endef

include $(BUILD_CUSTOM)

endif
