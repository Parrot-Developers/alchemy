###############################################################################
## @file properties.mk
## @author Y.M. Morgan
## @date 2013/10/23
##
## Manage build properties for boxinit.
###############################################################################

# Path of files
BUILD_PROP_FILE := $(TARGET_OUT_STAGING)/$(TARGET_DEFAULT_ETC_DESTDIR)/build.prop
BUILD_PROP_FILE_TMP := $(TARGET_OUT_BUILD)/build.prop

# Add some generic properties
TARGET_BUILD_PROPERTIES += \
	ro.build.alchemy.product=$(TARGET_PRODUCT) \
	ro.build.alchemy.variant=$(TARGET_PRODUCT_VARIANT) \
	ro.build.hostname=$(shell hostname)

# Put modules properties.
$(foreach __mod,$(ALL_BUILD_MODULES), \
	$(eval TARGET_BUILD_PROPERTIES += $(__modules.$(__mod).BUILD_PROPERTIES)) \
)

# Generate the file build.prop
# Generate in build dir and copy in staging
.PHONY: gen-build-prop
gen-build-prop:
	@mkdir -p $(dir $(BUILD_PROP_FILE_TMP))
	@mkdir -p $(dir $(BUILD_PROP_FILE))
	@rm -f $(BUILD_PROP_FILE_TMP)
	@echo "ro.build.date=`date`" >> $(BUILD_PROP_FILE_TMP)
	@echo "ro.build.date.utc=`date +%s`" >> $(BUILD_PROP_FILE_TMP)
	@$(foreach __line,$(TARGET_BUILD_PROPERTIES), \
		echo $(__line) >> $(BUILD_PROP_FILE_TMP); \
	)
	@cp -af $(BUILD_PROP_FILE_TMP) $(BUILD_PROP_FILE)

# Clean rule
.PHONY: gen-build-prop-clean
gen-build-prop-clean:
	@rm -f $(BUILD_PROP_FILE_TMP)
	@rm -f $(BUILD_PROP_FILE)

# Setup dependencies
post-build: gen-build-prop
clobber: gen-build-prop-clean
