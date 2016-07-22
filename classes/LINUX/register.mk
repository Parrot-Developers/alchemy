###############################################################################
## @file classes/LINUX/register.mk
## @author Y.M. Morgan
## @date 2013/05/08
##
## Register LINUX modules.
###############################################################################

ifneq ("$(LOCAL_HOST_MODULE)","")
  $(error $(LOCAL_PATH): LINUX not supported for host modules)
endif

###############################################################################
# Linux kernel.
###############################################################################

ifeq ("$(LOCAL_MODULE)", "linux")

# Override the module name...
LOCAL_MODULE_FILENAME := $(LOCAL_MODULE).done

LOCAL_MODULE_CLASS := LINUX

# General setup
LINUX_DIR := $(LOCAL_PATH)
LINUX_BUILD_DIR := $(call local-get-build-dir)
LINUX_HEADERS_DONE_FILE := $(LINUX_BUILD_DIR)/linux-headers.done
LOCAL_DONE_FILES += linux-headers.done

# Allows kernel to be of a different architecture
# ex: aarch64 for kernel and arm for system
ifndef TARGET_LINUX_ARCH
  TARGET_LINUX_ARCH := $(TARGET_ARCH)
endif

# Linux Toolchain
ifndef TARGET_LINUX_CROSS
  TARGET_LINUX_CROSS := $(TARGET_CROSS)
endif

# LINUX_SRCARCH is the name of the sub-directory in linux/arch
ifeq ("$(TARGET_LINUX_ARCH)","x64")
  LINUX_ARCH := x86_64
  LINUX_SRCARCH := x86
else ifeq ("$(TARGET_LINUX_ARCH)","aarch64")
  LINUX_ARCH := arm64
  LINUX_SRCARCH := arm64
else
  LINUX_ARCH := $(TARGET_LINUX_ARCH)
  LINUX_SRCARCH := $(TARGET_LINUX_ARCH)
endif

# How to build
LINUX_MAKE_ARGS := \
	ARCH="$(LINUX_ARCH)" \
	CC="$(CCACHE) $(TARGET_LINUX_CROSS)gcc" \
	CROSS_COMPILE="$(TARGET_LINUX_CROSS)" \
	-C $(LOCAL_PATH) \
	INSTALL_MOD_PATH="$(TARGET_OUT_STAGING)" \
	INSTALL_HDR_PATH="$(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR)/src/linux-headers" \
	O="$(LINUX_BUILD_DIR)" \
	$(TARGET_LINUX_MAKE_BUILD_ARGS)

# As a special exception, this variable is modified to make sure linux headers
# are created before anything happens
# FIXME needed even if linux is not actually built in some chroot env. A split
# would be easier. Previous check was actually wrong (ifndef instead of ifneq)
# leading to the prerequisite always added
TARGET_GLOBAL_PREREQUISITES += $(LINUX_HEADERS_DONE_FILE)

# Register in the system
$(module-add)

endif

###############################################################################
## The 'perf' tool is in the kernel source tree
###############################################################################

ifeq ("$(LOCAL_MODULE)", "perf")

# Override the module name...
LOCAL_MODULE_FILENAME := $(LOCAL_MODULE).done

LOCAL_MODULE_CLASS := LINUX

LOCAL_LIBRARIES := libelf

# Register in the system
$(module-add)

endif
