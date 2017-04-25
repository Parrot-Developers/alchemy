###############################################################################
## @file classes/BINARY/setup.mk
## @author F. Ferrand
## @date 2015/05/11
##
## Setup BINARY modules.
###############################################################################

###############################################################################
###############################################################################

# Supported source file extensions
_binary_extensions := cpp cxx cc c cu m s S

# Compilation banner
_binary-print-banner1 = \
	$(call print-banner1,"$(PRIVATE_MODE_MSG)$(PRIVATE_ARCH) $1",$(PRIVATE_MODULE),$(call path-from-top,$2))

# List of compilation flags that will be stored in a file used as dependency
# Whenever on of those flags changed, it will retrigger compilations
# Shall be = and not := because reference to some variables needs to be done during expansion
# TODO: add nvcc flags
_binary-objects-flags = \
	$(PRIVATE_MODE)_GLOBAL_C_INCLUDES \
	$(PRIVATE_MODE)_GLOBAL_ASFLAGS \
	$(PRIVATE_MODE)_GLOBAL_OBJCFLAGS \
	$(PRIVATE_MODE)_GLOBAL_VALAFLAGS \
	$(PRIVATE_MODE)_GLOBAL_PCHFLAGS \
	$(PRIVATE_MODE)_GLOBAL_LDLIBS \
	PRIVATE_GLOBAL_CFLAGS \
	PRIVATE_GLOBAL_CXXFLAGS \
	PRIVATE_GLOBAL_LDFLAGS \
	PRIVATE_C_INCLUDES \
	PRIVATE_ASFLAGS \
	PRIVATE_CFLAGS \
	PRIVATE_CXXFLAGS \
	PRIVATE_OBJCFLAGS \
	PRIVATE_VALAFLAGS \
	PRIVATE_PCH_INCLUDE \
	PRIVATE_LDFLAGS \
	PRIVATE_LDLIBS \
	PRIVATE_WARNINGS_CFLAGS \
	PRIVATE_WARNINGS_CXXFLAGS

_binary-get-objects-flags = \
	$(foreach __v,$(_binary-objects-flags), \
		$(__v) := $(strip $($(__v)))$(endl) \
	) \

# Under windows, use response file for linking to avoid reaching command line limit
# Note: it requires make >= 4.0 and the 'file' function
ifeq ("$(HOST_OS)","windows")
  ifeq ("$(MAKE_HAS_FILE_FUNC)","1")
    _binary_use_rsp_file := 1
  else
    _binary_use_rsp_file := 0
  endif
else
  _binary_use_rsp_file := 0
endif

# Generate or get response file
# $1: name of file (will be in 'PRIVATE_BUILD_DIR' with '.rsp' extension)
# $2: contents to put in file
ifneq ("$(_binary_use_rsp_file)","0")
_binary-gen-rsp-file = $(file > $(PRIVATE_BUILD_DIR)/$(PRIVATE_MODULE).$1.rsp,$2)
_binary-get-rsp-file = @$(PRIVATE_BUILD_DIR)/$(PRIVATE_MODULE).$1.rsp
else
_binary-gen-rsp-file =
_binary-get-rsp-file = $2
endif

###############################################################################
## Commands to generate a precompiled file.
###############################################################################

# $1 : mode (HOST / TARGET)
# $2 : destination
# $3 : source
define _internal-transform-h-to-gch
@mkdir -p $(dir $2)
$(call _binary-print-banner1,Precompile,$3)
$(Q) $(CCACHE) $(PRIVATE_CXX) \
	$(call normalize-c-includes-rel,$(PRIVATE_C_INCLUDES)) \
	$(call normalize-system-c-includes-rel,$($1_GLOBAL_C_INCLUDES)) \
	$(filter-out -std=%,$(PRIVATE_GLOBAL_CFLAGS)) \
	$(PRIVATE_GLOBAL_CXXFLAGS) \
	$(PRIVATE_WARNINGS_CXXFLAGS) \
	$(filter-out -std=%,$(PRIVATE_CFLAGS)) \
	$(PRIVATE_CXXFLAGS) \
	$($1_GLOBAL_PCHFLAGS) \
	-MD -MP -MF $(call path-from-top,$(2:.gch=.d)) -MT $(call path-from-top,$2) \
	-o $(call path-from-top,$2) \
	$(call path-from-top,$3)
$(call fix-deps-file,$(2:.gch=.d))
endef

transform-h-to-gch = $(call _internal-transform-h-to-gch,$(PRIVATE_MODE),$@,$<)

###############################################################################
## Command to compile a C++ file.
###############################################################################

# $1 : mode (HOST / TARGET)
# $2 : destination
# $3 : source
define _binary-cmd-cpp-to-o-internal
@mkdir -p $(dir $2)
$(call _binary-print-banner1,C++,$3)
$(Q) $(CCACHE) $(PRIVATE_CXX) \
	$(call normalize-c-includes-rel,$(PRIVATE_C_INCLUDES)) \
	$(call normalize-system-c-includes-rel,$($1_GLOBAL_C_INCLUDES)) \
	$(filter-out -std=%,$(PRIVATE_GLOBAL_CFLAGS)) \
	$(PRIVATE_GLOBAL_CXXFLAGS) \
	$(PRIVATE_WARNINGS_CXXFLAGS) \
	$(filter-out -std=%,$(PRIVATE_CFLAGS)) \
	$(PRIVATE_CXXFLAGS) \
	$(PRIVATE_PCH_INCLUDE) \
	-MD -MP -MF $(call path-from-top,$(2:.o=.d)) -MT $(call path-from-top,$2) \
	-o $(call path-from-top,$2) \
	-c $(call path-from-top,$3)
$(call fix-deps-file,$(2:.o=.d))
endef

transform-cpp-to-o = $(call _binary-cmd-cpp-to-o-internal,$(PRIVATE_MODE),$@,$<)
transform-cxx-to-o = $(call _binary-cmd-cpp-to-o-internal,$(PRIVATE_MODE),$@,$<)
transform-cc-to-o = $(call _binary-cmd-cpp-to-o-internal,$(PRIVATE_MODE),$@,$<)

###############################################################################
## Command to compile a C file.
###############################################################################

# $1 : mode (HOST / TARGET)
# $2 : destination
# $3 : source
define _binary-cmd-c-to-o-internal
@mkdir -p $(dir $2)
$(call _binary-print-banner1,C,$3)
$(Q) $(CCACHE) $(PRIVATE_CC) \
	$(call normalize-c-includes-rel,$(PRIVATE_C_INCLUDES)) \
	$(call normalize-system-c-includes-rel,$($1_GLOBAL_C_INCLUDES)) \
	$(PRIVATE_GLOBAL_CFLAGS) \
	$(PRIVATE_WARNINGS_CFLAGS) \
	$(PRIVATE_CFLAGS) \
	-MD -MP -MF $(call path-from-top,$(2:.o=.d)) -MT $(call path-from-top,$2) \
	-o $(call path-from-top,$2) \
	-c $(call path-from-top,$3)
$(call fix-deps-file,$(2:.o=.d))
endef

transform-c-to-o = $(call _binary-cmd-c-to-o-internal,$(PRIVATE_MODE),$@,$<)

###############################################################################
## Command to compile a Objective-C file.
###############################################################################

# $1 : mode (HOST / TARGET)
# $2 : destination
# $3 : source
define _binary-cmd-m-to-o-internal
@mkdir -p $(dir $2)
$(call _binary-print-banner1,ObjC,$3)
$(Q) $(CCACHE) $(PRIVATE_CC) \
	$(call normalize-c-includes-rel,$(PRIVATE_C_INCLUDES)) \
	$(call normalize-system-c-includes-rel,$($1_GLOBAL_C_INCLUDES)) \
	$(filter-out -std=%,$(PRIVATE_GLOBAL_CFLAGS)) \
	$($1_GLOBAL_OBJCFLAGS) \
	$(PRIVATE_WARNINGS_CFLAGS) \
	$(filter-out -std=%,$(PRIVATE_CFLAGS)) \
	$(PRIVATE_OBJCFLAGS) \
	-MD -MP -MF $(call path-from-top,$(2:.o=.d)) -MT $(call path-from-top,$2) \
	-o $(call path-from-top,$2) \
	-c $(call path-from-top,$3)
$(call fix-deps-file,$(2:.o=.d))
endef

transform-m-to-o = $(call _binary-cmd-m-to-o-internal,$(PRIVATE_MODE),$@,$<)

###############################################################################
## Command to compile a s/S file.
###############################################################################

# $1 : mode (HOST / TARGET)
# $2 : destination
# $3 : source
define _binary-cmd-s-to-o-internal
@mkdir -p $(dir $2)
$(call _binary-print-banner1,Asm,$3)
$(Q) $(CCACHE) $(PRIVATE_CC) \
	$(call normalize-c-includes-rel,$(PRIVATE_C_INCLUDES)) \
	$(call normalize-system-c-includes-rel,$($1_GLOBAL_C_INCLUDES)) \
	$($1_GLOBAL_ASFLAGS) \
	-D __ASSEMBLY__ \
	$(filter-out -std=%,$(PRIVATE_GLOBAL_CFLAGS)) \
	$(PRIVATE_WARNINGS_CFLAGS) \
	$(PRIVATE_ASFLAGS) \
	$(filter-out -std=%,$(PRIVATE_CFLAGS)) \
	-MD -MP -MF $(call path-from-top,$(2:.o=.d)) -MT $(call path-from-top,$2) \
	-o $(call path-from-top,$2) \
	-c $(call path-from-top,$3)
$(call fix-deps-file,$(2:.o=.d))
endef

transform-s-to-o = $(call _binary-cmd-s-to-o-internal,$(PRIVATE_MODE),$@,$<)
transform-S-to-o = $(call _binary-cmd-s-to-o-internal,$(PRIVATE_MODE),$@,$<)

###############################################################################
## Command to compile a cu file (cuda).
## Note: Only available for target
## NVCC dependencies generation have to be done in separate phase than compilation.
## The sed command is to simulate the -MP option of gcc, it will create an empty
## target for any dependencies.
###############################################################################

# $1 : mode (HOST / TARGET)
# $2 : destination
# $3 : source
define _binary-cmd-cu-to-o-internal
@mkdir -p $(dir $2)
$(call _binary-print-banner1,Cuda,$3)
@if [ -z "$(TARGET_NVCC)" ]; then \
	echo "TARGET_NVCC is not defined"; exit 1; \
fi

$(Q) $(TARGET_NVCC) \
	$(call normalize-c-includes-rel,$(PRIVATE_C_INCLUDES)) \
	$(call normalize-system-c-includes-rel,$(TARGET_GLOBAL_C_INCLUDES)) \
	$(TARGET_GLOBAL_NVCFLAGS) \
	$(PRIVATE_NVCFLAGS) \
	-ccbin $(PRIVATE_NVCC_CC) \
	-o $(call path-from-top,$2) \
	-c $(call path-from-top,$3)

@$(TARGET_NVCC) \
	$(call normalize-c-includes-rel,$(PRIVATE_C_INCLUDES)) \
	$(call normalize-system-c-includes-rel,$(TARGET_GLOBAL_C_INCLUDES)) \
	$(TARGET_GLOBAL_NVCFLAGS) \
	$(PRIVATE_NVCFLAGS) \
	-ccbin $(PRIVATE_NVCC_CC) \
	-M -MT $(call path-from-top,$2) \
	-o $(call path-from-top,$(2:.o=.d.tmp)) \
	$(call path-from-top,$3)
@cp -af $(call path-from-top,$(2:.o=.d.tmp)) $(call path-from-top,$(2:.o=.d))
@sed -e 's/^[^:]*: *//' \
	-e 's/\\$$//' \
	-e 's/^ *//' \
	-e 's/$$/:/' \
	< $(call path-from-top,$(2:.o=.d.tmp)) \
	>> $(call path-from-top,$(2:.o=.d))
@rm -f $(call path-from-top,$(2:.o=.d.tmp))
$(call fix-deps-file,$(2:.o=.d))

endef

transform-cu-to-o = $(call _binary-cmd-cu-to-o-internal,$(PRIVATE_MODE),$@,$<)

###############################################################################
## Commands to compile vala files.
###############################################################################

define _internal-transform-vala-to-c
$(call print-banner1,"$(PRIVATE_MODE_MSG)Valac",$(PRIVATE_MODULE),$(call path-from-top,$(PRIVATE_VALA_SOURCES)))
$(Q) $(HOST_OUT_STAGING)/$(HOST_DEFAULT_BIN_DESTDIR)/valac \
	$($1_GLOBAL_VALAFLAGS) \
	$(PRIVATE_VALAFLAGS) \
	-C -d $(PRIVATE_VALA_OUT_DIR) \
	-b $(PRIVATE_PATH) \
	--deps $(PRIVATE_VALA_DEPS_FILE) \
	$(PRIVATE_VALA_SOURCES)
endef

transform-vala-to-c = $(call _internal-transform-vala-to-c,$(PRIVATE_MODE))

###############################################################################
## Commands for running windres.
###############################################################################

define _internal-transform-rc-to-o
@mkdir -p $(dir $2)
$(call print-banner1,"$(PRIVATE_MODE_MSG)Rc",$(PRIVATE_MODULE),$(call path-from-top,$3))
$(Q) $(PRIVATE_WINDRES) \
	$(filter -D%,$(PRIVATE_GLOBAL_CFLAGS)) \
	$(filter -D%,$(PRIVATE_GLOBAL_CXXFLAGS)) \
	$(filter -D%,$(PRIVATE_CFLAGS)) \
	$(filter -D%,$(PRIVATE_CXXFLAGS)) \
	-o $(call path-from-top,$2) \
	$(call path-from-top,$3)
endef

transform-rc-to-o = $(call _internal-transform-rc-to-o,$(PRIVATE_MODE),$@,$<)

###############################################################################
## Commands for running ar.
###############################################################################

# Explicitly delete the archive first so that ar doesn't
# try to add to an existing archive.
define _internal-transform-o-to-static-lib
@mkdir -p $(dir $2)
$(call print-banner2,"$(PRIVATE_MODE_MSG)StaticLib",$(PRIVATE_MODULE),$(call path-from-top,$2))
$(call _binary-gen-rsp-file,objects-static,$(PRIVATE_ALL_OBJECTS))
@rm -f $2
$(Q) $(PRIVATE_AR) \
	$($1_GLOBAL_ARFLAGS) \
	$(PRIVATE_ARFLAGS) \
	$(call path-from-top,$2) \
	$(call _binary-get-rsp-file,objects-static,$(PRIVATE_ALL_OBJECTS))
endef

transform-o-to-static-lib = $(call _internal-transform-o-to-static-lib,$(PRIVATE_MODE),$@)

###############################################################################
## Commands to link a shared library.
###############################################################################

define _internal-transform-o-to-shared-lib-darwin
@mkdir -p $(dir $2)
$(call print-banner2,"$(PRIVATE_MODE_MSG)SharedLib",$(PRIVATE_MODULE),$(call path-from-top,$2))
$(call _binary-gen-rsp-file,objects-shared,$(PRIVATE_ALL_OBJECTS))
$(Q) $(PRIVATE_CXX) \
	$(PRIVATE_GLOBAL_LDFLAGS) \
	$(if $(call streq,$(USE_LINK_MAP_FILE),1), \
		-Wl$(comma)-map$(comma)$(basename $(call path-from-top,$2)).map \
	) \
	-shared \
	-Wl,-dead_strip \
	-Wl,-install_name,$($1_OUT_STAGING)/$($1_DEFAULT_LIB_DESTDIR)/$(notdir $2) \
	$(PRIVATE_LDFLAGS) \
	$(call _binary-get-rsp-file,objects-shared,$(PRIVATE_ALL_OBJECTS)) \
	$(call link-hook,$(PRIVATE_MODULE),$2, \
		$(PRIVATE_ALL_OBJECTS) \
		$(PRIVATE_ALL_STATIC_LIBRARIES) \
		$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
	$(foreach __lib, $(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES), -force_load $(__lib)) \
	$(PRIVATE_ALL_STATIC_LIBRARIES) \
	$(PRIVATE_ALL_SHARED_LIBRARIES) \
	-o $(call path-from-top,$2) \
	$(PRIVATE_LDLIBS) \
	$($1_GLOBAL_LDLIBS)
endef

define _internal-transform-o-to-shared-lib
@mkdir -p $(dir $2)
$(call print-banner2,"$(PRIVATE_MODE_MSG)SharedLib",$(PRIVATE_MODULE),$(call path-from-top,$2))
$(call _binary-gen-rsp-file,objects-shared,$(PRIVATE_ALL_OBJECTS))
$(Q) $(PRIVATE_CXX) \
	$(PRIVATE_GLOBAL_LDFLAGS) \
	$(if $(call streq,$(USE_LINK_MAP_FILE),1), \
		-Wl$(comma)-Map$(comma)$(basename $(call path-from-top,$2)).map \
	) \
	-shared \
	-Wl,-soname -Wl,$(notdir $2) \
	-Wl,--no-undefined \
	-Wl,--gc-sections \
	-Wl,--as-needed \
	$(if $(call streq,$($(PRIVATE_MODE)_OS),windows), \
		-Wl$(comma)--out-implib$(comma)$(call path-from-top,$2).a \
	) \
	$(PRIVATE_LDFLAGS) \
	$(call _binary-get-rsp-file,objects-shared,$(PRIVATE_ALL_OBJECTS)) \
	$(call link-hook,$(PRIVATE_MODULE),$2, \
		$(PRIVATE_ALL_OBJECTS) \
		$(PRIVATE_ALL_STATIC_LIBRARIES) \
		$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
	-Wl,--whole-archive \
	$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES) \
	-Wl,--no-whole-archive \
	$(PRIVATE_ALL_STATIC_LIBRARIES) \
	$(PRIVATE_ALL_SHARED_LIBRARIES) \
	-o $(call path-from-top,$2) \
	$(PRIVATE_LDLIBS) \
	$($1_GLOBAL_LDLIBS)
endef

transform-o-to-shared-lib = $(if $(call streq,$($(PRIVATE_MODE)_OS),darwin), \
	$(call _internal-transform-o-to-shared-lib-darwin,$(PRIVATE_MODE),$@) \
	, \
	$(call _internal-transform-o-to-shared-lib,$(PRIVATE_MODE),$@) \
)

###############################################################################
## Commands to link an executable.
###############################################################################

define _internal-transform-o-to-executable-darwin
@mkdir -p $(dir $2)
$(call print-banner2,"$(PRIVATE_MODE_MSG)Executable",$(PRIVATE_MODULE),$(call path-from-top,$2))
$(call _binary-gen-rsp-file,objects-executable,$(PRIVATE_ALL_OBJECTS))
$(Q) $(PRIVATE_CXX) \
	$(PRIVATE_GLOBAL_LDFLAGS) \
	$(if $(call streq,$(USE_LINK_MAP_FILE),1), \
		-Wl$(comma)-map$(comma)$(basename $(call path-from-top,$2)).map \
	) \
	-Wl,-dead_strip \
	$(PRIVATE_LDFLAGS) \
	$(call _binary-get-rsp-file,objects-executable,$(PRIVATE_ALL_OBJECTS)) \
	$(call link-hook,$(PRIVATE_MODULE),$2, \
		$(PRIVATE_ALL_OBJECTS) \
		$(PRIVATE_ALL_STATIC_LIBRARIES) \
		$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
	$(foreach __lib, $(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES), -force_load $(__lib)) \
	$(PRIVATE_ALL_STATIC_LIBRARIES) \
	$(PRIVATE_ALL_SHARED_LIBRARIES) \
	-o $(call path-from-top,$2) \
	$(PRIVATE_LDLIBS) \
	$($1_GLOBAL_LDLIBS)
endef

define _internal-transform-o-to-executable
@mkdir -p $(dir $2)
$(call print-banner2,"$(PRIVATE_MODE_MSG)Executable",$(PRIVATE_MODULE),$(call path-from-top,$2))
$(call _binary-gen-rsp-file,objects-executable,$(PRIVATE_ALL_OBJECTS))
$(Q) $(PRIVATE_CXX) \
	$(PRIVATE_GLOBAL_LDFLAGS) \
	$(if $(call streq,$(USE_LINK_MAP_FILE),1), \
		-Wl$(comma)-Map$(comma)$(basename $(call path-from-top,$2)).map \
	) \
	-Wl,--gc-sections \
	-Wl,--as-needed \
	$(PRIVATE_LDFLAGS) \
	$(call _binary-get-rsp-file,objects-executable,$(PRIVATE_ALL_OBJECTS)) \
	$(call link-hook,$(PRIVATE_MODULE),$2, \
		$(PRIVATE_ALL_OBJECTS) \
		$(PRIVATE_ALL_STATIC_LIBRARIES) \
		$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
	-Wl,--whole-archive \
	$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES) \
	-Wl,--no-whole-archive \
	$(PRIVATE_ALL_STATIC_LIBRARIES) \
	$(PRIVATE_ALL_SHARED_LIBRARIES) \
	-o $(call path-from-top,$2) \
	$(PRIVATE_LDLIBS) \
	$($1_GLOBAL_LDLIBS)
endef

transform-o-to-executable = $(if $(call streq,$($(PRIVATE_MODE)_OS),darwin), \
	$(call _internal-transform-o-to-executable-darwin,$(PRIVATE_MODE),$@) \
	, \
	$(call _internal-transform-o-to-executable,$(PRIVATE_MODE),$@) \
)

###############################################################################
## Copy to staging/final directory if needed, with strip in final dir
## $1 : HOST/TARGET mode
## $2 : source file
## $3 : destination file
###############################################################################

define _binary-copy-to-final-strip
$3: $2
	@echo "Strip: $(call path-from-top,$2) => $(call path-from-top,$3)"
	@mkdir -p $(dir $3)
	$(Q) $($1_STRIP) -o $3 $2
endef

_binary-copy-to-staging = \
	$(if $(call strneq,$(LOCAL_NO_COPY_TO_STAGING),1), \
		$(eval $(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $3) \
		$(eval $(_module_installed_stamp_file): $3) \
		$(eval $(call copy-one-file,$2,$3)) \
	)

_binary-copy-to-final = \
	$(if $(and $(call strneq,$(LOCAL_NO_COPY_TO_STAGING),1),$(call streq,$1,TARGET),$(wildcard $(TARGET_OUT_FINAL))), \
		$(eval $(LOCAL_MODULE): $3) \
		$(if $(or $(call streq,$(TARGET_NOSTRIP_FINAL),1),$(filter $(TARGET_STRIP_FILTER),$(notdir $2))), \
			$(eval $(call copy-one-file,$2,$3)) \
			, \
			$(eval $(call _binary-copy-to-final-strip,$1,$2,$3)) \
		) \
	)
