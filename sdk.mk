###############################################################################
## @file sdk.mk
## @author Y.M. Morgan
## @date 2013/04/20
##
## Generate a sdk to be used as a base.
###############################################################################

SDK_DIR := $(TARGET_OUT)/sdk
SDK_TGZ := $(TARGET_OUT)/sdk-$(TARGET_PRODUCT_FULL_NAME).tar.gz
MAKESDK_SCRIPT := $(BUILD_SYSTEM)/scripts/makesdk.py

ifeq ("$(V)","1")
  MAKESDK_SCRIPT += -v
endif

.PHONY: sdk
sdk: dump-xml
	@echo "Sdk: start"
	$(Q) $(MAKESDK_SCRIPT) $(DUMP_DATABASE_XML_FILE) \
		$(HOST_OUT_BUILD) $(HOST_OUT_STAGING) \
		$(TARGET_OUT_BUILD) $(TARGET_OUT_STAGING) $(SDK_DIR)
	@rm -f $(SDK_TGZ)
	$(Q) tar -C $(dir $(SDK_DIR)) -czf $(SDK_TGZ) $(notdir $(SDK_DIR))
	@echo "Sdk: done -> $(SDK_DIR) ($(SDK_TGZ))"

.PHONY: sdk-clean
sdk-clean:
	$(Q) rm -rf $(SDK_DIR)
	$(Q) rm -f $(SDK_TGZ)

# Setup dependencies
sdk: post-build
clobber: sdk-clean
