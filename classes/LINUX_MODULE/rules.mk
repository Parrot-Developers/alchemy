###############################################################################
## @file classes/LINUX_MODULE/rules.mk
## @author Y.M. Morgan
## @date 2016/03/20
##
## Rules for LINUX_MODULE modules.
###############################################################################

LINUX_MODULE_OBJ_DIR := $(call local-get-build-dir)/obj
LINUX_MODULE_KBUILD := $(LINUX_MODULE_OBJ_DIR)/Kbuild
LINUX_MODULE_SRC_FILES := $(addprefix $(LINUX_MODULE_OBJ_DIR)/src/, $(LOCAL_SRC_FILES))

# Copy sources files as KBuild needs to be at the same place than sources
$(foreach __f, $(LOCAL_SRC_FILES), \
	$(eval $(call copy-one-file,$(LOCAL_PATH)/$(__f),$(LINUX_MODULE_OBJ_DIR)/src/$(__f))) \
)

###############################################################################
###############################################################################

_module_msg := $(if $(_mode_host),Host )LinuxModule

_module_def_cmd_build := _linux-module-def-cmd-build
_module_def_cmd_install := _linux-module-def-cmd-install
_module_def_cmd_clean := _linux-module-def-cmd-clean

include $(BUILD_SYSTEM)/classes/GENERIC/rules.mk

###############################################################################
###############################################################################

$(LINUX_MODULE_KBUILD): .FORCE
	$(_linux-module-gen-kbuild)

$(_module_built_stamp_file): $(LINUX_MODULE_KBUILD)
$(_module_built_stamp_file): $(LINUX_MODULE_SRC_FILES)

###############################################################################
###############################################################################

$(LOCAL_TARGETS): PRIVATE_OBJ_DIR := $(LINUX_MODULE_OBJ_DIR)
$(LOCAL_TARGETS): PRIVATE_OBJECTS := $(addprefix src/,$(LOCAL_SRC_FILES:.c=.o))
$(LOCAL_TARGETS): PRIVATE_C_INCLUDES := $(addprefix -I$(LOCAL_PATH)/, $(call uniq2, $(dir $(LOCAL_SRC_FILES))))
$(LOCAL_TARGETS): PRIVATE_C_INCLUDES += $(addprefix -I, $(LOCAL_C_INCLUDES))
$(LOCAL_TARGETS): PRIVATE_CFLAGS := $(LOCAL_CFLAGS)
$(LOCAL_TARGETS): PRIVATE_KBUILD := $(LINUX_MODULE_KBUILD)

# LINUX_XXX variables can NOT be used here, they may not be defined yet
# So the ARCH argument is given later when invoking make
ifeq ("$(TARGET_OS_FLAVOUR:-chroot=)","native")
$(LOCAL_TARGETS): PRIVATE_LINUX_BUILD_DIR := /lib/modules/$(TARGET_LINUX_RELEASE)/build
$(LOCAL_TARGETS): PRIVATE_KBUILD_FLAGS := \
	INSTALL_MOD_PATH=$(TARGET_OUT_STAGING)
else
$(LOCAL_TARGETS): PRIVATE_LINUX_BUILD_DIR := $(strip \
	$(if $(__modules.linux.SDK), \
		$(__modules.linux.SDK)/$(TARGET_ROOT_DESTDIR)/src/linux-sdk \
		, \
		$(call module-get-build-dir,linux) \
	))
$(LOCAL_TARGETS): PRIVATE_KBUILD_FLAGS := \
	KERNELSRCDIR=$(PRIVATE_LINUX_BUILD_DIR) \
	KERNELBUILDDIR=$(PRIVATE_LINUX_BUILD_DIR) \
	INSTALL_MOD_PATH=$(TARGET_OUT_STAGING)
endif
