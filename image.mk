###############################################################################
## @file image.mk
## @author Y.M. Morgan
## @date 2012/12/13
##
## Image generation.
###############################################################################

MKFS_SCRIPT := $(BUILD_SYSTEM)/scripts/mkfs.py

ifeq ("$(V)","1")
  MKFS_SCRIPT += -v
endif

# Script that will modify mode/uid/gid of files while generating the image
FIXSTAT := $(BUILD_SYSTEM)/scripts/fixstat.py \
	--user-file=$(TARGET_OUT_FINAL)/etc/passwd \
	--group-file=$(TARGET_OUT_FINAL)/etc/group \
	$(foreach __f,$(TARGET_PERMISSIONS_FILES), \
		--permissions-file=$(__f) \
	)

# Apply default permissions (quite restrictives) only if other rules are present
ifneq ("$(TARGET_PERMISSIONS_FILES)","")
  FIXSTAT += --use-default
endif

###############################################################################
## Generic image generation macro.
## $1: image type.
## $2: image file name.
## $3 : extra arguments.
###############################################################################
define gen-image
	$(Q) cd $(TARGET_OUT_FINAL); \
		find . $(if $(call streq,$1,cpio),-name 'boot' -prune -o) \
			! -name '.' -printf '%P\n' | $(FIXSTAT) | \
			$(MKFS_SCRIPT) --fstype $1 $3 $2
endef

###############################################################################
## Generate image in plf format.
## $1: image file name.
###############################################################################
PLFTOOL ?= plftool
MK_KERNEL_PLF ?= mk_kernel_plf
define gen-image-plf
	$(Q) if [ -f "$(TARGET_OUT_FINAL)/boot/zImage" ]; then \
		$(MK_KERNEL_PLF) \
			"ignore-boot.cfg" \
			$(TARGET_OUT_FINAL)/boot/zImage \
			$(TARGET_OUT_BUILD)/linux/.config \
			$(TARGET_OUT)/kernel.plf; \
		$(PLFTOOL) -a u_data=$(TARGET_OUT)/kernel.plf $1; \
	elif [ "$(TARGET_CHROOT)" = "0" ]; then \
		echo "Image plf: no kernel image found"; \
	fi
	$(Q) cd $(TARGET_OUT_FINAL); \
		find . -path './boot/*' -a ! -name '*.dtb' -prune -o ! -name '.' -printf '%P\n' \
			| $(FIXSTAT) | plfbatch '-a u_unixfile="&"' $1
ifneq ("$(TARGET_IMAGE_PATH_MAP_FILE)","")
	$(Q) PLFTOOL=$(PLFTOOL) $(BUILD_SYSTEM)/scripts/plfremap.py \
		$(TARGET_IMAGE_PATH_MAP_FILE) $1
endif
endef

###############################################################################
## Specialized macros.
## $1: image file name.
###############################################################################
gen-image-tar = $(call gen-image,tar,$1,$(TARGET_IMAGE_OPTIONS))
gen-image-cpio = $(call gen-image,cpio,$1,$(TARGET_IMAGE_OPTIONS) --devnode "dev/console:622:0:0:c:5:1")
gen-image-ext2 = $(call gen-image,ext2,$1,$(TARGET_IMAGE_OPTIONS))
gen-image-ext3 = $(call gen-image,ext3,$1,$(TARGET_IMAGE_OPTIONS))
gen-image-ext4 = $(call gen-image,ext4,$1,$(TARGET_IMAGE_OPTIONS))

###############################################################################
## Generate rules to buil an image.
## $1: image type.
###############################################################################
define image-rules
$(eval __image-$1-file := $(TARGET_OUT)/$(TARGET_PRODUCT_FULL_NAME).$1)
.PHONY: image-$1 image-$1-gz image-$1-bz2
.PHONY: image-$1-clean image-$1-gz-clean image-$1-bz2-clean
__image-$1-internal: image-$1-clean
	@echo "Image $1: start"
	$(Q) if [ ! -d $(TARGET_OUT_FINAL) ]; then \
		echo "Image $1: missing final directory"; exit 1; \
	fi
	$(call gen-image-$1,$(__image-$1-file))
image-$1: __image-$1-internal
	@echo "Image $1: done -> $(__image-$1-file)"
image-$1-gz: __image-$1-internal
	@echo "Image $1: compressing"
	$(Q) gzip $(__image-$1-file)
	@echo "Image $1: done -> $(__image-$1-file).gz"
image-$1-bz2: __image-$1-internal
	@echo "Image $1: compressing"
	$(Q) bzip2 $(__image-$1-file)
	@echo "Image $1: done -> $(__image-$1-file).bz2"
image-$1-clean:
	$(Q) rm -f $(__image-$1-file)
	$(Q) rm -f $(__image-$1-file).gz
	$(Q) rm -f $(__image-$1-file).bz2
image-all-clean: image-$1-clean
__image-$1-internal: post-final
endef

# Generate all rules
$(eval $(call image-rules,plf))
$(eval $(call image-rules,tar))
$(eval $(call image-rules,cpio))
$(eval $(call image-rules,ext2))
$(eval $(call image-rules,ext3))
$(eval $(call image-rules,ext4))

# Clean all images (used in image-rules macro)
.PHONY: image-all-clean
image-all-clean:

# Shortcut when TARGET_IMAGE_FORMAT is defined
.PHONY: image image-clean
image: image-$(subst .,-,$(TARGET_IMAGE_FORMAT))
image-clean: image-$(subst .,-,$(TARGET_IMAGE_FORMAT))-clean

# Compatibility shortcut
.PHONY: plf plf-clean
plf: image-plf
plf-clean: image-plf-clean
image-cpio: image-cpio-gz

# Additional plf clean
.PHONY: __image-plf-clean-extra
image-plf-clean: __image-plf-clean-extra
__image-plf-clean-extra:
	$(Q) rm -f $(TARGET_OUT)/kernel.plf

# Clean all images when clobber is done
clobber: image-all-clean

###############################################################################
## Additional step for cpio when asked to link it in linux image.
###############################################################################
ifneq ("$(TARGET_LINUX_LINK_CPIO_IMAGE)","0")
.PHONY: __image-cpio-relink-linux
image-cpio: __image-cpio-relink-linux
__image-cpio-relink-linux: __image-cpio-internal
	@echo "Rebuilding linux kernel with initramfs"
	$(Q) gzip < $(__image-cpio-file) > $(LINUX_BUILD_DIR)/rootfs.cpio.gz
	$(Q) $(MAKE) $(LINUX_MAKE_ARGS)
	$(call linux-copy-images)
endif

###############################################################################
## Generate the fixstat script so it can be used externally.
###############################################################################
.PHONY: fixstat-script
fixstat-script:
	@( \
		echo "#!/bin/sh"; \
		echo "$(FIXSTAT) \"\$$@\""; \
	) > $(TARGET_OUT)/fixstat.sh
	@chmod +x $(TARGET_OUT)/fixstat.sh

.PHONY: fixstat-script-clean
fixstat-script-clean:
	@rm -f $(TARGET_OUT)/fixstat.sh

###############################################################################
## Setup dependencies
###############################################################################
post-build: fixstat-script
image-all-clean: fixstat-script-clean
