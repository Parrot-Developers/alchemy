###############################################################################
## @file sdk.mk
## @author Y.M. Morgan
## @date 2013/04/20
##
## Generate a sdk to be used as a base.
###############################################################################

SDK_DIR := $(TARGET_OUT)/sdk
SDK_TAR := $(TARGET_OUT)/sdk-$(TARGET_PRODUCT_FULL_NAME).tar
SDK_TGZ := $(SDK_TAR).gz
SDK_TBZ2 := $(SDK_TAR).bz2
MAKESDK_SCRIPT := $(BUILD_SYSTEM)/scripts/makesdk.py

ifneq ("$(V)","0")
  MAKESDK_SCRIPT += -v
endif

# $1 type of output (directory, tar, tar.gz, tar.bz2)
define sdk-gen
	$(Q) $(MAKESDK_SCRIPT) $(DUMP_DATABASE_XML_FILE) \
		$(HOST_OUT_BUILD) $(HOST_OUT_STAGING) \
		$(TARGET_OUT_BUILD) $(TARGET_OUT_STAGING) $1
endef

# Generate sdk directory + archive in tar.gz
.PHONY: sdk
sdk: dump-xml
	@echo "Sdk: start"
	$(call sdk-gen,$(SDK_DIR))
	$(Q) tar -C $(dir $(SDK_DIR)) -czf $(SDK_TGZ) $(notdir $(SDK_DIR))
	@echo "Sdk: done -> $(SDK_DIR) ($(SDK_TGZ))"

.PHONY: sdk-tar
sdk-tar: dump-xml
	@echo "Sdk: start"
	$(call sdk-gen,$(SDK_TAR))
	@echo "Sdk: done -> $(SDK_TAR)"

.PHONY: sdk-tar-gz
sdk-tar-gz: dump-xml
	@echo "Sdk: start"
	$(call sdk-gen,$(SDK_TGZ))
	@echo "Sdk: done -> $(SDK_TGZ)"

.PHONY: sdk-tar-bz2
sdk-tar-bz2: dump-xml
	@echo "Sdk: start"
	$(call sdk-gen,$(SDK_TBZ2))
	@echo "Sdk: done -> $(SDK_TBZ2)"

.PHONY: sdk-clean
sdk-clean:
	$(Q) rm -rf $(SDK_DIR)
	$(Q) rm -f $(SDK_TAR)
	$(Q) rm -f $(SDK_TGZ)
	$(Q) rm -f $(SDK_TBZ2)

# Setup dependencies
sdk: post-build
sdk-tar: post-build
sdk-tar-gz: post-build
sdk-tar-be2: post-build
clobber: sdk-clean
