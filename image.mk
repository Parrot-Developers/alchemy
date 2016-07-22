###############################################################################
## @file image.mk
## @author Y.M. Morgan
## @date 2012/12/13
##
## Image generation.
###############################################################################

MKFS_SCRIPT := $(BUILD_SYSTEM)/scripts/mkfs.py
SPARSE_SCRIPT := $(BUILD_SYSTEM)/scripts/sparse.py

# Script that will modify mode/uid/gid of files while generating the image
FIXSTAT := $(BUILD_SYSTEM)/scripts/fixstat.py \
	--user-file=$(TARGET_OUT_FINAL)/$(TARGET_DEFAULT_ETC_DESTDIR)/passwd \
	--group-file=$(TARGET_OUT_FINAL)/$(TARGET_DEFAULT_ETC_DESTDIR)/group \
	$(foreach __f,$(TARGET_PERMISSIONS_FILES), \
		--permissions-file=$(__f) \
	)

# Apply default permissions (quite restrictives) only if other rules are present
ifneq ("$(TARGET_PERMISSIONS_FILES)","")
  FIXSTAT += --use-default
endif

ifneq ("$(V)","0")
  MKFS_SCRIPT += -v
  SPARSE_SCRIPT += -v
  FIXSTAT += -v
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

define gen-image-sparse
	$(call gen-image,$1,$2.tmp,$3)
	$(Q) $(SPARSE_SCRIPT) --sparse $2.tmp $2
	$(Q) rm -f $2.tmp
endef

# Extract some part of the TARGET_IMAGE_OPTIONS variables
# $1 : option to extract (argument shall be enclosed betwwen double quotes)
# TARGET_IMAGE_OPTIONS := \
#	--mkubifs="-m 0x800 -e 0x1f000 -c 2047 -x none -F" \
#	--ubinize="-p 0x20000 -m 0x800 -s 2048 $(TARGET_CONFIG_DIR)/ubinize.cfg"
image-extract-args = \
	`echo '$(TARGET_IMAGE_OPTIONS)' | sed -e 's%.*$1="\([^"]\+\)".*%\1%'`

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
endef

###############################################################################
## Generate image in ubi format.
## $1: image file name.
## TODO: pass options properly
## TODO: generate cfg with relative file paths
###############################################################################
MKUBIFS ?= $(wildcard /usr/sbin/mkfs.ubifs)
UBINIZE ?= $(wildcard /usr/sbin/ubinize)

define gen-image-ubi
	@if [ -z "$(MKUBIFS)" -o -z "$(UBINIZE)" ]; then \
		echo "Missing mkfs.ubifs/ubinize tools"; \
		exit 1; \
	fi
	$(Q) chmod -R g-w,o-w $(TARGET_OUT_FINAL)
	$(Q) fakeroot $(MKUBIFS) \
		$(call image-extract-args,--mkubifs) \
		-r $(TARGET_OUT_FINAL) \
		$1.ubifs
	$(Q) cd $(TARGET_OUT) && $(UBINIZE) \
		-o $1 \
		$(call image-extract-args,--ubinize)
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
gen-image-sext2 = $(call gen-image-sparse,ext2,$1,$(TARGET_IMAGE_OPTIONS))
gen-image-sext3 = $(call gen-image-sparse,ext3,$1,$(TARGET_IMAGE_OPTIONS))
gen-image-sext4 = $(call gen-image-sparse,ext4,$1,$(TARGET_IMAGE_OPTIONS))

###############################################################################
## Generate rules to build an image.
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
$(eval $(call image-rules,sext2))
$(eval $(call image-rules,sext3))
$(eval $(call image-rules,sext4))
$(eval $(call image-rules,ubi))

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
