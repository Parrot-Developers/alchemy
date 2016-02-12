###############################################################################
## @file linuxkernelmodule.mk
## @author R. Lefèvre
## @date 2014/09/11
##
## Build a Linux kernel module.
###############################################################################

ifeq ("$(LOCAL_MODULE_FILENAME)","")
LOCAL_MODULE_FILENAME := $(LOCAL_MODULE).ko
endif

LINUX_MODULE := $(call local-get-build-dir)/$(LOCAL_MODULE_FILENAME)
LINUX_MODULE_OBJ_DIR := $(call local-get-build-dir)/obj
LINUX_MODULE_KBUILD := $(LINUX_MODULE_OBJ_DIR)/Kbuild
LINUX_MODULE_SRC_FILES := $(addprefix $(LINUX_MODULE_OBJ_DIR)/src/, $(LOCAL_SRC_FILES))


# LINUX_XXX variables can NOT be used here, they may not be defined yet
# So the ARCH argument is given later when invoking make
ifeq ("$(TARGET_OS_FLAVOUR:-chroot=)","native")
$(LINUX_MODULE): PRIVATE_LINUX_BUILD_DIR := /lib/modules/$(shell uname -r)/build
$(LINUX_MODULE): PRIVATE_KBUILD_FLAGS := \
	INSTALL_MOD_PATH=$(TARGET_OUT_STAGING)
else
LOCAL_LIBRARIES := linux
$(LINUX_MODULE): PRIVATE_LINUX_BUILD_DIR := $(strip \
	$(if $(__modules.linux.SDK), \
		$(__modules.linux.SDK)/usr/src/linux-sdk \
		, \
		$(call module-get-build-dir,linux) \
	))
$(LINUX_MODULE): PRIVATE_KBUILD_FLAGS := \
	KERNELSRCDIR=$(PRIVATE_LINUX_BUILD_DIR) \
	KERNELBUILDDIR=$(PRIVATE_LINUX_BUILD_DIR) \
	INSTALL_MOD_PATH=$(TARGET_OUT_STAGING)
endif

.PHONY: $(LOCAL_MODULE)-clean
$(LOCAL_MODULE)-clean: PRIVATE_NAME := $(LOCAL_MODULE_FILENAME)
$(LOCAL_MODULE)-clean:
	$(Q) if test -d $(PRIVATE_BUILD_DIR)/obj; then find $(PRIVATE_BUILD_DIR)/obj -type f -delete; fi
	$(Q) rm -rf $(PRIVATE_BUILD_DIR)/obj/.tmp_versions
	$(Q) rm -f $(TARGET_OUT_STAGING)/lib/modules/*/extra/$(PRIVATE_NAME)

# Create Kbuild file
$(LINUX_MODULE_KBUILD): $(LOCAL_PATH)/$(USER_MAKEFILE_NAME)
	$(call print-banner2,"Kbuild",$(PRIVATE_MODULE),$(call path-from-top,$@))
	$(Q) mkdir -p $(dir $@)
	$(Q)( \
		echo "obj-m := $(PRIVATE_NAME:.ko=.o)"; \
		echo "$(PRIVATE_NAME:.ko=-y) := $(PRIVATE_OBJECTS)"; \
		echo "ccflags-y := $(PRIVATE_INCLUDES)"; \
		echo "ccflags-y += $(PRIVATE_CFLAGS)"; \
	) > $@

# Copy sources files as KBuild needs to be at the same place than sources
$(foreach __f, $(LOCAL_SRC_FILES), \
	$(eval $(call copy-one-file,$(LOCAL_PATH)/$(__f),$(LINUX_MODULE_OBJ_DIR)/src/$(__f))) \
)

$(LINUX_MODULE): PRIVATE_OBJ_DIR := $(LINUX_MODULE_OBJ_DIR)
$(LINUX_MODULE): PRIVATE_NAME := $(LOCAL_MODULE_FILENAME)
$(LINUX_MODULE): PRIVATE_OBJECTS := $(addprefix src/,$(LOCAL_SRC_FILES:.c=.o))
$(LINUX_MODULE): PRIVATE_INCLUDES := $(addprefix -I$(LOCAL_PATH)/, $(call uniq2, $(dir $(LOCAL_SRC_FILES))))
$(LINUX_MODULE): PRIVATE_INCLUDES += $(addprefix -I, $(LOCAL_C_INCLUDES))
$(LINUX_MODULE): PRIVATE_CFLAGS := $(LOCAL_CFLAGS)

# Build module
$(LINUX_MODULE): $(LINUX_MODULE_KBUILD) $(LINUX_MODULE_SRC_FILES)
	$(call print-banner2,"Linux module",$(PRIVATE_MODULE),$(call path-from-top,$@))
	$(Q) $(MAKE) -C $(PRIVATE_LINUX_BUILD_DIR) M=$(PRIVATE_OBJ_DIR) \
		$(if $(wildcard $(PRIVATE_LINUX_BUILD_DIR)/linuxarch),ARCH=$$(cat $(PRIVATE_LINUX_BUILD_DIR)/linuxarch)) \
		$(PRIVATE_KBUILD_FLAGS) \
		CROSS_COMPILE=$(if $(TARGET_LINUX_CROSS),$(TARGET_LINUX_CROSS),$(TARGET_CROSS)) \
		modules
	$(Q) $(MAKE) -C $(PRIVATE_LINUX_BUILD_DIR) M=$(PRIVATE_OBJ_DIR) \
		$(if $(wildcard $(PRIVATE_LINUX_BUILD_DIR)/linuxarch),ARCH=$$(cat $(PRIVATE_LINUX_BUILD_DIR)/linuxarch)) \
		$(PRIVATE_KBUILD_FLAGS) \
		CROSS_COMPILE=$(if $(TARGET_LINUX_CROSS),$(TARGET_LINUX_CROSS),$(TARGET_CROSS)) \
		modules_install
	$(Q) mv -f $(PRIVATE_OBJ_DIR)/$(PRIVATE_NAME) $@

# Register as a custom build in the system
include $(BUILD_CUSTOM)
