###############################################################################
## @file gobject-introspection-rules.mk
## @author R. Lefèvre
## @date 2015/05/11
##
## Generate rules for building a gobject-introspection typelib library.
###############################################################################

# Prepend some directories in include list
LOCAL_C_INCLUDES := $(build_dir) $(LOCAL_PATH) $(LOCAL_C_INCLUDES)

###############################################################################
## List of sources
###############################################################################

c_sources := $(addprefix $(LOCAL_PATH)/,$(filter %.c,$(LOCAL_SRC_FILES)))
c_headers := $(addprefix $(LOCAL_PATH)/,$(filter %.h,$(LOCAL_SRC_FILES)))

all_sources := $(c_headers) $(c_sources)

g_ir_scanner_exe := $(HOST_OUT_STAGING)/usr/bin/g-ir-scanner
g_ir_compiler_exe := $(HOST_OUT_STAGING)/usr/bin/g-ir-compiler

###############################################################################
## Commands to compile a Gir file.
###############################################################################

define transform-c-to-gir
@mkdir -p $(dir $@)
$(call print-banner2,"Gir",$(PRIVATE_MODULE),$(call path-from-top,$@))
$(Q) mkdir -p $(PRIVATE_OBJ_DIR)
$(Q) cd $(PRIVATE_OBJ_DIR) && \
	GI_SCANNER_DISABLE_CACHE=1 \
	XDG_DATA_DIRS=$($(PRIVATE_MODE)XDG_DATA_DIRS) \
		$(g_ir_scanner_exe) \
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
		$(filter -L%,$(TARGET_GLOBAL_LDFLAGS_SHARED)) \
		$(filter -L%,$(PRIVATE_LDFLAGS)) \
		$(PRIVATE_LDLIBS) \
		$(PRIVATE_ALL_SOURCES)
$(Q) cp -f $@ $(TARGET_OUT_STAGING)/usr/share/gir-1.0/
endef

###############################################################################
## Commands to compile a type library.
###############################################################################

define transform-gir-to-typelib
@mkdir -p $(dir $@)
$(call print-banner2,"Typelib",$(PRIVATE_MODULE),$(call path-from-top,$@))
$(Q) cd $(PRIVATE_OBJ_DIR) && $(g_ir_compiler_exe) --output $@ $<
endef

$(LOCAL_TARGETS): PRIVATE_GI_NAMESPACE := $(LOCAL_GI_NAMESPACE)
$(LOCAL_TARGETS): PRIVATE_GI_LIBRARY := $(LOCAL_GI_LIBRARY)
$(LOCAL_TARGETS): PRIVATE_GI_ID_PREFIX := $(LOCAL_GI_ID_PREFIX)
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(build_dir)/$(LOCAL_MODULE_FILENAME:.typelib=.gir)
$(LOCAL_TARGETS): PRIVATE_OBJ_DIR := $(build_dir)/obj
$(LOCAL_TARGETS): PRIVATE_CFLAGS := $(LOCAL_CFLAGS)
$(LOCAL_TARGETS): PRIVATE_LDFLAGS := $(LOCAL_LDFLAGS)
$(LOCAL_TARGETS): PRIVATE_LDLIBS := $(LOCAL_LDLIBS)
$(LOCAL_TARGETS): PRIVATE_C_INCLUDES := $(LOCAL_C_INCLUDES)
$(LOCAL_TARGETS): PRIVATE_ALL_SOURCES := $(all_sources)
