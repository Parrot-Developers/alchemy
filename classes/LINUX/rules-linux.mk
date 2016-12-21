###############################################################################
## @file classes/LINUX/rules-linux.mk
## @author Y.M. Morgan
## @date 2016/03/20
##
## Rules for LINUX modules.
###############################################################################

_module_msg := $(if $(_mode_host),Host )Linux

include $(BUILD_SYSTEM)/classes/GENERIC/rules.mk

###############################################################################
###############################################################################

# Make sure this variable is defined (so make --warn-undefined-variables is quiet)
# It can be defined by the user makefile to specify a list of headers to be
# copied from linux source tree (list of absolute path)
# They will be copied in $(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR)/include/linux
ifndef LINUX_EXPORTED_HEADERS
  LINUX_EXPORTED_HEADERS :=
endif

# Linux image to generate
ifndef TARGET_LINUX_IMAGE
  ifeq ("$(TARGET_LINUX_GENERATE_UIMAGE)","1")
    TARGET_LINUX_IMAGE := uImage
  else ifeq ("$(TARGET_LINUX_ARCH)","x86")
    TARGET_LINUX_IMAGE := bzImage
  else ifeq ("$(TARGET_LINUX_ARCH)","x64")
    TARGET_LINUX_IMAGE := bzImage
  else ifeq ("$(TARGET_LINUX_ARCH)","arm")
    TARGET_LINUX_IMAGE := zImage
  else ifeq ("$(TARGET_LINUX_ARCH)","aarch64")
    TARGET_LINUX_IMAGE := Image
  else
    TARGET_LINUX_IMAGE := zImage
  endif
endif

###############################################################################
###############################################################################

# Linux configuration file or target
LINUX_CONFIG_FILE := $(call module-get-config,$(LOCAL_MODULE))
LINUX_CONFIG_FILE_IS_TARGET := $(false)
ifeq ("$(wildcard $(LINUX_CONFIG_FILE))","")
  ifdef LINUX_CONFIG_TARGET
    LINUX_CONFIG_FILE := $(LINUX_DIR)/arch/$(LINUX_SRCARCH)/configs/$(LINUX_CONFIG_TARGET)
    LINUX_CONFIG_FILE_IS_TARGET := $(true)
  else ifdef LINUX_DEFAULT_CONFIG_TARGET
    LINUX_CONFIG_FILE := $(LINUX_DIR)/arch/$(LINUX_SRCARCH)/configs/$(LINUX_DEFAULT_CONFIG_TARGET)
    LINUX_CONFIG_TARGET := $(LINUX_DEFAULT_CONFIG_TARGET)
    LINUX_CONFIG_FILE_IS_TARGET := $(true)
  else
    ifeq ("$(wildcard $(LINUX_DEFAULT_CONFIG_FILE))","")
      $(error No linux config file found)
    else
      LINUX_CONFIG_FILE := $(LINUX_DEFAULT_CONFIG_FILE)
    endif
  endif
endif

###############################################################################
###############################################################################

# Headers to be copied in $(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR)
LINUX_EXPORTED_HEADERS_OVER := \
	include/linux/media.h \
	include/linux/videodev2.h \
	include/linux/v4l2-common.h \
	include/linux/v4l2-mediabus.h \
	include/linux/v4l2-subdev.h \
	include/linux/i2c-dev.h \
	include/linux/hid.h \
	include/linux/hidraw.h \
	include/linux/hiddev.h \
	include/linux/ethtool.h \
	include/linux/net.h \
	include/linux/uinput.h \
	include/linux/input.h \
	include/linux/watchdog.h \
	include/linux/spi/spidev.h \
	include/linux/uhid.h \
	include/linux/ion.h \
	include/linux/sock_diag.h \
	include/linux/inet_diag.h \
	include/linux/iio/events.h \
	include/linux/iio/types.h \
	include/linux/cn_proc.h \
	include/linux/prctl.h \
	include/linux/input-event-codes.h

###############################################################################
###############################################################################

# Macro to copy a kernel image from boot directory to staging directory
# $1 image file to copy from arch/boot directory
linux-copy-image = \
	$(if $(call streq,$(TARGET_LINUX_IMAGE),$1), \
		if [ -f $(LINUX_BUILD_DIR)/arch/$(LINUX_SRCARCH)/boot/$1 ]; then \
			cp -af $(LINUX_BUILD_DIR)/arch/$(LINUX_SRCARCH)/boot/$1 $(TARGET_OUT_STAGING)/boot; \
		fi; \
	)

define linux-copy-images
	$(Q) $(call linux-copy-image,uImage)
	$(Q) $(call linux-copy-image,Image)
	$(Q) $(call linux-copy-image,zImage)
	$(Q) $(call linux-copy-image,bzImage)
endef

###############################################################################
###############################################################################

ifneq ("$(TARGET_LINUX_LINK_CPIO_IMAGE)","0")

define linux-setup-cpio-config
	@ : > $(LINUX_BUILD_DIR)/rootfs.cpio.gz
	$(call kconfig-enable-opt,CONFIG_BLK_DEV_INITRD,$(LINUX_BUILD_DIR)/.config)
	$(call kconfig-set-opt,CONFIG_INITRAMFS_SOURCE,\"rootfs.cpio.gz\",$(LINUX_BUILD_DIR)/.config)
	$(call kconfig-set-opt,CONFIG_INITRAMFS_ROOT_UID,0,$(LINUX_BUILD_DIR)/.config)
	$(call kconfig-set-opt,CONFIG_INITRAMFS_ROOT_GID,0,$(LINUX_BUILD_DIR)/.config)
	$(call kconfig-disable-opt,CONFIG_INITRAMFS_COMPRESSION_NONE,$(LINUX_BUILD_DIR)/.config)
	$(call kconfig-enable-opt,CONFIG_INITRAMFS_COMPRESSION_GZIP,$(LINUX_BUILD_DIR)/.config)
endef

else

define linux-setup-cpio-config
endef

endif

###############################################################################
###############################################################################

# Setup config in build dir
ifneq ("$(LINUX_CONFIG_FILE_IS_TARGET)","")

# Use linux target
define linux-setup-config
	@mkdir -p $(LINUX_BUILD_DIR)
	$(Q) $(MAKE) $(LINUX_MAKE_ARGS) $(LINUX_CONFIG_TARGET)
endef

# Copy it somewhere so after a dirclean it is not completely lost...
define linux-save-config
	$(Q) cp -af $(LINUX_BUILD_DIR)/.config $(TARGET_CONFIG_DIR)/$(LINUX_CONFIG_TARGET).config
	@echo "The linux config file has been saved in $(TARGET_CONFIG_DIR)/$(LINUX_CONFIG_TARGET).config"
	@echo "If you do a 'linux-dirclean' you will need to do a 'linux-restore-config' to restore it"
	@echo "Otherwise the default target '$(LINUX_CONFIG_TARGET)' will be used again."
endef

# Rule to create .config
$(LINUX_BUILD_DIR)/.config:
	+$(linux-setup-config)
	+$(linux-setup-cpio-config)

else # ifneq ("$(LINUX_CONFIG_FILE_IS_TARGET)","")

# Use a file
define linux-setup-config
	@mkdir -p $(LINUX_BUILD_DIR)
	@$(call __config-apply-sed,linux,$(LINUX_BUILD_DIR)/linux.config.tmp,$(LINUX_CONFIG_FILE))
	$(Q) cp -af $(LINUX_BUILD_DIR)/linux.config.tmp $(LINUX_BUILD_DIR)/.config
endef

define linux-save-config
	$(Q) cp -af $(LINUX_BUILD_DIR)/.config $(LINUX_CONFIG_FILE)
endef

# Rule to create .config
$(LINUX_BUILD_DIR)/.config: $(LINUX_CONFIG_FILE)
	+$(linux-setup-config)
	+$(linux-setup-cpio-config)

endif # ifneq ("$(LINUX_CONFIG_FILE_IS_TARGET)","")

###############################################################################
###############################################################################

# Generate everything for the sdk (so we can build external kernel modules from it)
# Inspired from <linux>/scripts/package/builddeb, 'Build header package' section
LINUX_SDK_DIR := $(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR)/src/linux-sdk
define linux-gen-sdk
	$(Q) :> $(LINUX_BUILD_DIR)/sdksrcfiles
	$(Q) :> $(LINUX_BUILD_DIR)/sdkobjfiles
	$(Q) (cd $(PRIVATE_PATH); \
		find . -name Makefile -o -name Kconfig\* -o -name \*.pl \
		>> $(LINUX_BUILD_DIR)/sdksrcfiles)
	$(Q) (cd $(PRIVATE_PATH); \
		find arch/$(LINUX_SRCARCH)/include include scripts -type f \
		>> $(LINUX_BUILD_DIR)/sdksrcfiles)
$(if $(call streq,$(LINUX_ARCH),arm), \
	$(Q) (cd $(PRIVATE_PATH); \
		find arch/$(LINUX_SRCARCH)/*/include -type f \
		>> $(LINUX_BUILD_DIR)/sdksrcfiles) \
)
	$(Q) (cd $(LINUX_BUILD_DIR); \
		[ ! -d arch/$(LINUX_SRCARCH)/include ] || \
		find arch/$(LINUX_SRCARCH)/include include scripts .config Module.symvers -type f \
		>> $(LINUX_BUILD_DIR)/sdkobjfiles)
	$(Q) mkdir -p $(LINUX_SDK_DIR)
	$(Q) tar -C $(PRIVATE_PATH) -cf - -T $(LINUX_BUILD_DIR)/sdksrcfiles | \
		tar -C $(LINUX_SDK_DIR) -xf -
	$(Q) tar -C $(LINUX_BUILD_DIR) -cf - -T $(LINUX_BUILD_DIR)/sdkobjfiles | \
		tar -C $(LINUX_SDK_DIR) -xf -
	$(Q) rm -f $(LINUX_BUILD_DIR)/sdksrcfiles
	$(Q) rm -f $(LINUX_BUILD_DIR)/sdkobjfiles
	$(Q) echo "$(LINUX_ARCH)" > $(LINUX_SDK_DIR)/linuxarch
endef

###############################################################################
###############################################################################

# Avoid compiling kernel at same time than header installation by adding a prerequisite
$(LINUX_BUILD_DIR)/$(LOCAL_MODULE_FILENAME): $(LINUX_BUILD_DIR)/.config $(LINUX_HEADERS_DONE_FILE)
	@mkdir -p $(LINUX_BUILD_DIR)/drivers/parrot/nand
	@echo "Checking linux kernel config: $(LINUX_CONFIG_FILE)"
	$(Q) yes "" 2>/dev/null | $(MAKE) $(LINUX_MAKE_ARGS) oldconfig
	@echo "Building linux kernel"
ifneq ("$(TARGET_LINUX_LINK_CPIO_IMAGE)","0")
	@ : > $(LINUX_BUILD_DIR)/rootfs.cpio.gz
endif
	$(Q) $(MAKE) $(LINUX_MAKE_ARGS)
	@echo "Installing linux kernel modules"
	$(Q) rm -rf $(TARGET_OUT_STAGING)/lib/modules
	$(Q) if grep -q "CONFIG_MODULES=y" $(LINUX_BUILD_DIR)/.config; then \
		$(MAKE) $(LINUX_MAKE_ARGS) modules_install ; \
	else \
		echo "CONFIG_MODULES not set in kernel config, ignoring"; \
	fi
	$(Q) rm -f  $(TARGET_OUT_STAGING)/lib/modules/*/build
	$(Q) rm -f  $(TARGET_OUT_STAGING)/lib/modules/*/source
	@echo "Installing linux kernel images"
ifneq ("$(TARGET_LINUX_GENERATE_UIMAGE)","0")
	$(Q) $(MAKE) $(LINUX_MAKE_ARGS) uImage
endif
ifeq ("$(TARGET_LINUX_IMAGE)","uImage")
	$(Q) $(MAKE) $(LINUX_MAKE_ARGS) uImage
endif
	@mkdir -p $(TARGET_OUT_STAGING)/boot
	$(call linux-copy-images)
ifneq ("$(TARGET_LINUX_DEVICE_TREE_NAMES)","")
	$(foreach __f,$(TARGET_LINUX_DEVICE_TREE_NAMES), \
		$(Q) cp -af $(LINUX_BUILD_DIR)/arch/$(LINUX_SRCARCH)/boot/dts/$(__f) \
			$(TARGET_OUT_STAGING)/boot/$(endl) \
	)
endif
	$(Q) cp -af $(LINUX_BUILD_DIR)/vmlinux $(TARGET_OUT_STAGING)/boot
	$(call linux-gen-sdk)
	$(Q) cp -af $(LINUX_BUILD_DIR)/.config $(LINUX_BUILD_DIR)/linux.config
	$(Q) echo "$(LINUX_ARCH)" > $(LINUX_BUILD_DIR)/linuxarch
	@echo "Linux kernel built"
	@touch $@

###############################################################################
###############################################################################

# Linux headers
# Order-only dependency on config to avoid parallel execution of linux makefile
.PHONY: linux-headers
linux-headers: $(LINUX_HEADERS_DONE_FILE)
$(LINUX_HEADERS_DONE_FILE): | $(LINUX_BUILD_DIR)/.config
ifneq ("$(LINUX_ARCH)","um")
	@mkdir -p $(LINUX_BUILD_DIR)
	@mkdir -p $(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR)/src/linux-headers
	@echo "Installing linux kernel headers"
	$(Q) $(MAKE) $(LINUX_MAKE_ARGS) headers_install
	@mkdir -p $(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR)/include/linux
	@mkdir -p $(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR)/include/linux/spi
	$(foreach header,$(LINUX_EXPORTED_HEADERS), \
		$(Q) install -m 0644 -p -D $(header) \
			$(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR)/include/linux/$(notdir $(header))$(endl) \
	)
	$(foreach header,$(LINUX_EXPORTED_HEADERS_OVER), \
		$(Q) if [ -f $(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR)/src/linux-headers/$(header) ]; then \
			install -m 0644 -p -D $(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR)/src/linux-headers/$(header) \
				$(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR)/$(header); \
		fi$(endl) \
	)
endif
	@echo "Installing linux kernel headers: done"
	@touch $@

###############################################################################
###############################################################################

# Custom clean rule. LOCAL_MODULE_FILENAME already deleted by common rule
# make clean may fail, so ignore its error
.PHONY: linux-clean
linux-clean:
	$(Q) if [ -d $(LINUX_BUILD_DIR) ]; then \
		$(MAKE) $(LINUX_MAKE_ARGS) --ignore-errors \
			clean || echo "Ignoring clean errors"; \
	fi
	$(Q) rm -rf $(TARGET_OUT_STAGING)/lib/modules
	$(Q) rm -f $(TARGET_OUT_STAGING)/boot/Image
	$(Q) rm -f $(TARGET_OUT_STAGING)/boot/zImage
	$(Q) rm -f $(TARGET_OUT_STAGING)/boot/bzImage
	$(Q) rm -f $(TARGET_OUT_STAGING)/boot/uImage
	$(Q) rm -f $(LINUX_HEADERS_DONE_FILE)
	$(Q) rm -rf $(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR)/src/linux-headers
	$(Q) rm -rf $(LINUX_SDK_DIR)
	$(foreach header,$(LINUX_EXPORTED_HEADERS),\
		$(Q) rm -f $(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR)/include/linux/$(notdir $(header))$(endl) \
	)
	$(foreach header,$(LINUX_EXPORTED_HEADERS_OVER),\
		$(Q) rm -f $(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR)/$(header)$(endl) \
	)
ifneq ("$(TARGET_LINUX_LINK_CPIO_IMAGE)","0")
	$(Q) rm -f $(LINUX_BUILD_DIR)/rootfs.cpio.gz
endif

###############################################################################
###############################################################################

# Kernel configuration
.PHONY: linux-menuconfig
linux-menuconfig: $(LINUX_BUILD_DIR)/.config
	@echo "Configuring linux kernel: $(LINUX_CONFIG_FILE)"
	$(if $(call is-var-defined,custom.linux.config.sedfiles), \
		$(error Sed files found. We cannot save in this case))
	$(Q) $(MAKE) $(LINUX_MAKE_ARGS) menuconfig
	$(Q) $(linux-save-config)

.PHONY: linux-xconfig
linux-xconfig: $(LINUX_BUILD_DIR)/.config
	@echo "Configuring linux kernel: $(LINUX_CONFIG_FILE)"
	$(if $(call is-var-defined,custom.linux.config.sedfiles), \
		$(error Sed files found. We cannot save in this case))
	$(Q) $(MAKE) $(LINUX_MAKE_ARGS) xconfig
	$(Q) $(linux-save-config)

.PHONY: linux-config
linux-config: linux-xconfig

# Restore linux config file when using a config target
.PHONY: linux-restore-config
linux-restore-config:
ifneq ("$(LINUX_CONFIG_FILE_IS_TARGET)","")
	@mkdir -p $(LINUX_BUILD_DIR)
	@echo "Restoring linux config: $(TARGET_CONFIG_DIR)/$(LINUX_CONFIG_TARGET).config"
	$(Q) cp -af $(TARGET_CONFIG_DIR)/$(LINUX_CONFIG_TARGET).config $(LINUX_BUILD_DIR)/.config
endif

.PHONY: linux-check-config
linux-check-config: $(LINUX_BUILD_DIR)/.config
	@echo "Checking linux config: $(LINUX_CONFIG_FILE)"
	$(Q) yes "" 2>/dev/null | $(MAKE) $(LINUX_MAKE_ARGS) oldconfig
	$(Q) diff -u $(LINUX_CONFIG_FILE) $(LINUX_BUILD_DIR)/.config || true

.PHONY: linux-reset-config
linux-reset-config:
	@echo "Reseting linux config: $(LINUX_CONFIG_FILE)"
	$(Q) rm -f $(LINUX_BUILD_DIR)/.config
	+$(Q) $(linux-setup-config)

###############################################################################
###############################################################################

# Default rule to invoke kernel specific targets (like cscope, tags, help ...)
.PHONY: linux-%
linux-%: $(LINUX_BUILD_DIR)/.config
	@echo "Building linux kernel $* target with $(LINUX_CONFIG_FILE)"
	$(Q) $(MAKE) $(LINUX_MAKE_ARGS) $*
	$(Q) $(linux-save-config)
