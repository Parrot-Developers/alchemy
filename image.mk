###############################################################################
## @file image.mk
## @author Y.M. Morgan
## @date 2012/12/13
##
## Image generation.
###############################################################################

MKFS_SCRIPT := $(BUILD_SYSTEM)/scripts/mkfs.py
SPARSE_SCRIPT := $(BUILD_SYSTEM)/scripts/sparse.py
VERITY_SCRIPT := $(BUILD_SYSTEM)/scripts/prepare-dm-verity-uboot-script.sh

# Script that will modify mode/uid/gid of files while generating the image
FIXSTAT := $(BUILD_SYSTEM)/scripts/fixstat.py

# Apply default permissions (quite restrictives) only if other rules are present
ifneq ("$(TARGET_PERMISSIONS_FILES)","")
FIXSTAT += \
	--use-default \
	--user-file=$(TARGET_OUT_FINAL)/$(TARGET_DEFAULT_ETC_DESTDIR)/passwd \
	--group-file=$(TARGET_OUT_FINAL)/$(TARGET_DEFAULT_ETC_DESTDIR)/group \
	$(foreach __f,$(TARGET_PERMISSIONS_FILES), --permissions-file=$(__f))
endif

ifneq ("$(V)","0")
  MKFS_SCRIPT += -v
  SPARSE_SCRIPT += -v
  FIXSTAT += -v
endif

MKUBIFS ?= $(wildcard /usr/sbin/mkfs.ubifs)
UBINIZE ?= $(wildcard /usr/sbin/ubinize)
VERITYSETUP ?= $(wildcard /sbin/veritysetup)
MKE2FS ?= $(wildcard /sbin/mke2fs)

###############################################################################
## Generic image generation macro.
## $1: image type.
## $2: image file name.
## $3: extra arguments.
## $4: env/wrapper for MKFS_SCRIPT
###############################################################################
define gen-image
	$(Q) cd $(TARGET_OUT_FINAL); \
		find . $(if $(call streq,$1,cpio),-name 'boot' -prune -o) \
			-name '.DS_Store' -prune -o \
			! -name '.' -print | $(FIXSTAT) | \
			$4 $(MKFS_SCRIPT) --fstype $1 $3 $2
endef

define gen-image-sparse
	$(call gen-image,$1,$2.tmp,$3,$4)
	$(Q) $(SPARSE_SCRIPT) --sparse $2.tmp $2
	$(Q) rm -f $2.tmp
endef

define gen-image-verity
	$(call gen-image,$1,$2.tmp,$3,$4)
	$(Q) test -e "$(VERITYSETUP)" || (echo "Missing veritysetup" && false)
	$(Q) $(VERITYSETUP) format --data-block-size=1024 --hash-offset=`stat -c "%s" $2.tmp` $2.tmp $2.tmp | $(VERITY_SCRIPT) "$(TARGET_IMAGE_VERITY_OPTIONS)" > $(TARGET_OUT_FINAL)/boot/dm-verity-uboot-script.txt
	$(Q) mv $2.tmp $2
endef

define gen-image-sparse-verity
	$(call gen-image-verity,$1,$2.tmp,$3,$4)
	$(Q) $(SPARSE_SCRIPT) --sparse $2.tmp $2
	$(Q) rm -f $2.tmp
endef

###############################################################################
## Generate image in plf format.
## $1: image file name.
###############################################################################
PLFTOOL ?= plftool
MK_KERNEL_PLF ?= mk_kernel_plf

ifndef gen-kernel-plf
gen-kernel-plf = \
	$(MK_KERNEL_PLF) \
		"ignore-boot.cfg" \
		$(TARGET_OUT_FINAL)/boot/zImage \
		$(TARGET_OUT_BUILD)/linux/.config \
		$1;
endif

define gen-image-plf
	$(Q) if [ -f "$(TARGET_OUT_FINAL)/boot/zImage" ]; then \
		$(call gen-kernel-plf,$(TARGET_OUT)/kernel.plf) \
		$(PLFTOOL) -a u_data=$(TARGET_OUT)/kernel.plf $1; \
	elif [ "$(TARGET_CHROOT)" = "0" ]; then \
		echo "Image plf: no kernel image found"; \
	fi
	$(Q) cd $(TARGET_OUT_FINAL); \
		find . -path './boot/*' -a ! -name '*.dtb' -prune -o \
			-name '.DS_Store' -prune -o \
			! -name '.' -print \
			| $(FIXSTAT) | plfbatch '-a u_unixfile="&"' $1
endef

###############################################################################
## Specialized macros.
## $1: image file name.
###############################################################################
gen-image-tar = $(call gen-image,tar,$1,$(TARGET_IMAGE_OPTIONS),$(empty))
gen-image-cpio = $(call gen-image,cpio,$1,$(TARGET_IMAGE_OPTIONS) --devnode "dev/console:622:0:0:c:5:1",$(empty))
ifeq ("$(TARGET_IMAGE_FAST)","1")
gen-image-ext2 = $(call gen-image,ext2,$1,$(TARGET_IMAGE_OPTIONS) --fast, MKE2FS=$(MKE2FS) fakeroot)
gen-image-ext3 = $(call gen-image,ext3,$1,$(TARGET_IMAGE_OPTIONS) --fast, MKE2FS=$(MKE2FS) fakeroot)
gen-image-ext4 = $(call gen-image,ext4,$1,$(TARGET_IMAGE_OPTIONS) --fast, MKE2FS=$(MKE2FS) fakeroot)
else
gen-image-ext2 = $(call gen-image,ext2,$1,$(TARGET_IMAGE_OPTIONS),$(empty))
gen-image-ext3 = $(call gen-image,ext3,$1,$(TARGET_IMAGE_OPTIONS),$(empty))
gen-image-ext4 = $(call gen-image,ext4,$1,$(TARGET_IMAGE_OPTIONS),$(empty))
endif
gen-image-sext2 = $(call gen-image-sparse,ext2,$1,$(TARGET_IMAGE_OPTIONS),$(empty))
gen-image-sext3 = $(call gen-image-sparse,ext3,$1,$(TARGET_IMAGE_OPTIONS),$(empty))
gen-image-sext4 = $(call gen-image-sparse,ext4,$1,$(TARGET_IMAGE_OPTIONS),$(empty))
gen-image-vext4 = $(call gen-image-verity,ext4,$1,$(TARGET_IMAGE_OPTIONS),$(empty))
gen-image-svext4 = $(call gen-image-sparse-verity,ext4,$1,$(TARGET_IMAGE_OPTIONS),$(empty))
gen-image-ubi = $(call gen-image,ubi,$1, \
	$(TARGET_IMAGE_OPTIONS) --ubinize-root=$(TARGET_OUT), \
	MKUBIFS=$(MKUBIFS) UBINIZE=$(UBINIZE) fakeroot)

###############################################################################
## Generate rules to build an image.
## $1: image type.
###############################################################################
define image-rules
$(eval __image-$1-file := $(TARGET_OUT)/$(TARGET_PRODUCT_FULL_NAME).$1)
.PHONY: image-$1 image-$1-gz image-$1-bz2 image-$1-zip
.PHONY: image-$1-clean image-$1-gz-clean image-$1-bz2-clean image-$1-zip-clean
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
	$(Q) if [ "$(shell which pigz 2>/dev/null)" = "" ]; then \
		gzip $(__image-$1-file); \
	else \
		pigz $(__image-$1-file); \
	fi
	@echo "Image $1: done -> $(__image-$1-file).gz"
image-$1-bz2: __image-$1-internal
	@echo "Image $1: compressing"
	$(Q) if [ "$(shell which pbzip2 2>/dev/null)" = "" ]; then \
		bzip2 $(__image-$1-file); \
	else \
		pbzip2 $(__image-$1-file); \
	fi
	@echo "Image $1: done -> $(__image-$1-file).bz2"
image-$1-zip: __image-$1-internal
	@echo "Image $1: compressing"
	$(Q) if [ "$(shell which pigz 2>/dev/null)" = "" ]; then \
		zip --junk-paths $(__image-$1-file).zip $(__image-$1-file); \
	else \
		pigz --zip $(__image-$1-file) --stdout > $(__image-$1-file).zip; \
	fi
	$(Q) /sbin/blkid -c /dev/null -o value -s UUID $(__image-$1-file) | \
		zip --archive-comment $(__image-$1-file).zip
	@echo "Image $1: done -> $(__image-$1-file).zip"
image-$1-clean:
	$(Q) rm -f $(__image-$1-file)
	$(Q) rm -f $(__image-$1-file).gz
	$(Q) rm -f $(__image-$1-file).bz2
	$(Q) rm -f $(__image-$1-file).zip
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
$(eval $(call image-rules,vext4))
$(eval $(call image-rules,svext4))
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
