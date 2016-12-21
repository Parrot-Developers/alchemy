###############################################################################
## @file classes/GI_TYPELIB/setup.mk
## @author Y.M. Morgan
## @date 2016/03/20
##
## Setup GI_TYPELIB modules.
###############################################################################

g_ir_scanner := $(HOST_OUT_STAGING)/$(HOST_DEFAULT_BIN_DESTDIR)/g-ir-scanner
g_ir_compiler := $(HOST_OUT_STAGING)/$(HOST_DEFAULT_BIN_DESTDIR)/g-ir-compiler

define transform-c-to-gir
@mkdir -p $(dir $@)
$(call print-banner2,"Gir",$(PRIVATE_MODULE),$(call path-from-top,$@))
@mkdir -p $(PRIVATE_OBJ_DIR)
$(Q) cd $(PRIVATE_OBJ_DIR) && \
	GI_SCANNER_DISABLE_CACHE=1 \
	XDG_DATA_DIRS=$($(PRIVATE_MODE)XDG_DATA_DIRS) \
		$(g_ir_scanner) \
		--quiet \
		--output $@ \
		--library $(PRIVATE_GI_LIBRARY:lib%=%) \
		--namespace $(PRIVATE_GI_NAMESPACE) \
		--identifier-prefix $(PRIVATE_GI_ID_PREFIX) \
		--nsversion=1.0 \
		--no-libtool --warn-all \
		$(call normalize-c-includes,$(PRIVATE_C_INCLUDES)) \
		$(filter -I%,$(TARGET_GLOBAL_CFLAGS)) \
		$(filter -I%,$(PRIVATE_CFLAGS)) \
		$(filter -L%,$(TARGET_GLOBAL_LDFLAGS)) \
		$(filter -L%,$(PRIVATE_LDFLAGS)) \
		$(PRIVATE_LDLIBS) \
		$(PRIVATE_ALL_SOURCES)
@mkdir -p $(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR)/share/gir-1.0
$(Q) cp -af $@ $(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR)/share/gir-1.0
endef

define transform-gir-to-typelib
@mkdir -p $(dir $@)
$(call print-banner2,"Typelib",$(PRIVATE_MODULE),$(call path-from-top,$@))
$(Q) cd $(PRIVATE_OBJ_DIR) && $(g_ir_compiler) --output $@ $<
endef
