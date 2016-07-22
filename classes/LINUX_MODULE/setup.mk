###############################################################################
## @file classes/LINUX_MODULE/setup.mk
## @author Y.M. Morgan
## @date 2016/03/20
##
## Setup LINUX_MODULE modules.
###############################################################################

# Create Kbuild file
define _linux-module-gen-kbuild
	@mkdir -p $(dir $(PRIVATE_KBUILD))
	@( \
		echo "obj-m := $(PRIVATE_MODULE_FILENAME:.ko=.o)"; \
		echo "$(PRIVATE_MODULE_FILENAME:.ko=-y) := $(PRIVATE_OBJECTS)"; \
		echo "ccflags-y := $(PRIVATE_C_INCLUDES)"; \
		echo "ccflags-y += $(PRIVATE_CFLAGS)"; \
	) > $(PRIVATE_KBUILD).tmp
	$(call update-file-if-needed,$(PRIVATE_KBUILD),$(PRIVATE_KBUILD).tmp)
endef

# Build module
define _linux-module-def-cmd-build
	$(Q) $(MAKE) -C $(PRIVATE_LINUX_BUILD_DIR) M=$(PRIVATE_OBJ_DIR) \
		$(if $(wildcard $(PRIVATE_LINUX_BUILD_DIR)/linuxarch),ARCH=$$(cat $(PRIVATE_LINUX_BUILD_DIR)/linuxarch)) \
		$(PRIVATE_KBUILD_FLAGS) \
		CROSS_COMPILE=$(if $(TARGET_LINUX_CROSS),$(TARGET_LINUX_CROSS),$(TARGET_CROSS)) \
		modules
endef

# Install module
define _linux-module-def-cmd-install
	$(Q) $(MAKE) -C $(PRIVATE_LINUX_BUILD_DIR) M=$(PRIVATE_OBJ_DIR) \
		$(if $(wildcard $(PRIVATE_LINUX_BUILD_DIR)/linuxarch),ARCH=$$(cat $(PRIVATE_LINUX_BUILD_DIR)/linuxarch)) \
		$(PRIVATE_KBUILD_FLAGS) \
		CROSS_COMPILE=$(if $(TARGET_LINUX_CROSS),$(TARGET_LINUX_CROSS),$(TARGET_CROSS)) \
		modules_install
	$(Q) cp -af $(PRIVATE_OBJ_DIR)/$(PRIVATE_MODULE_FILENAME) $(PRIVATE_BUILD_DIR)/$(PRIVATE_MODULE_FILENAME)
endef

define _linux-module-def-cmd-clean
	$(Q) if [ -f $(PRIVATE_KBUILD) ]; then \
		$(MAKE) -C $(PRIVATE_LINUX_BUILD_DIR) M=$(PRIVATE_OBJ_DIR) \
			$(if $(wildcard $(PRIVATE_LINUX_BUILD_DIR)/linuxarch),ARCH=$$(cat $(PRIVATE_LINUX_BUILD_DIR)/linuxarch)) \
			$(PRIVATE_KBUILD_FLAGS) \
			CROSS_COMPILE=$(if $(TARGET_LINUX_CROSS),$(TARGET_LINUX_CROSS),$(TARGET_CROSS)) \
			clean || echo "Ignoring clean errors"; \
	fi
	$(Q) rm -f $(PRIVATE_BUILD_DIR)/$(PRIVATE_MODULE_FILENAME)
	$(Q) rm -f $(TARGET_OUT_STAGING)/lib/modules/*/extra/$(PRIVATE_MODULE_FILENAME)
endef
