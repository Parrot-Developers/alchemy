###############################################################################
## @file binary-setup.mk
## @author F. Ferrand
## @date 2015/05/11
##
## This file defines commands used to build libraries and applications.
###############################################################################

###############################################################################
## Commands to generate a precompiled file.
###############################################################################

define transform-h-to-gch
@mkdir -p $(dir $@)
$(call print-banner1,"Precompile",$(PRIVATE_MODULE),$(call path-from-top,$<))
$(call check-pwd-is-top-dir)
$(Q)$(CCACHE) $(PRIVATE_CXX) \
	$(call normalize-c-includes-rel,$(PRIVATE_C_INCLUDES)) \
	$(call normalize-system-c-includes-rel,$(TARGET_GLOBAL_C_INCLUDES)) \
	$(TARGET_GLOBAL_CFLAGS) $(TARGET_GLOBAL_CXXFLAGS) $(WARNINGS_CXXFLAGS) \
	$(TARGET_GLOBAL_CXXFLAGS_$(PRIVATE_COMPILER_FLAVOUR)) \
	$(TARGET_GLOBAL_CFLAGS_$(PRIVATE_COMPILER_FLAVOUR)) \
	$(WARNINGS_CXXFLAGS_$(PRIVATE_COMPILER_FLAVOUR)) \
	$(TARGET_GLOBAL_CFLAGS_$(PRIVATE_ARCH)) \
	$(TARGET_GLOBAL_CFLAGS_$(PRIVATE_ARCH)_$(PRIVATE_COMPILER_FLAVOUR)) \
	$(PRIVATE_CFLAGS) $(PRIVATE_CXXFLAGS) \
	$(TARGET_GLOBAL_PCH_FLAGS) -MMD -MP -MF $(@:.gch=.d) -MT $@ -o $@ \
	$(call path-from-top,$<)
$(call fix-deps-file,$(@:.gch=.d))
endef

###############################################################################
## Commands to compile a C++ file.
###############################################################################

define transform-cpp-to-o
@mkdir -p $(dir $@)
$(call print-banner1,"$(PRIVATE_ARCH) C++",$(PRIVATE_MODULE),$(call path-from-top,$<))
$(call check-pwd-is-top-dir)
$(Q)$(CCACHE) $(PRIVATE_CXX) \
	$(call normalize-c-includes-rel,$(PRIVATE_C_INCLUDES)) \
	$(call normalize-system-c-includes-rel,$(TARGET_GLOBAL_C_INCLUDES)) \
	$(filter-out -std=%,$(TARGET_GLOBAL_CFLAGS)) $(TARGET_GLOBAL_CXXFLAGS) $(WARNINGS_CXXFLAGS) \
	$(TARGET_GLOBAL_CXXFLAGS_$(PRIVATE_COMPILER_FLAVOUR)) \
	$(filter-out -std=%,$(TARGET_GLOBAL_CFLAGS_$(PRIVATE_COMPILER_FLAVOUR))) \
	$(WARNINGS_CXXFLAGS_$(PRIVATE_COMPILER_FLAVOUR)) \
	$(filter-out -std=%,$(TARGET_GLOBAL_CFLAGS_$(PRIVATE_ARCH))) \
	$(filter-out -std=%,$(TARGET_GLOBAL_CFLAGS_$(PRIVATE_ARCH)_$(PRIVATE_COMPILER_FLAVOUR))) \
	$(PRIVATE_PCH_INCLUDE) \
	$(filter-out -std=%,$(PRIVATE_CFLAGS)) $(PRIVATE_CXXFLAGS) \
	-c -MMD -MP -MF $(@:.o=.d) -MT $@ -o $@ \
	$(call path-from-top,$<)
$(call fix-deps-file,$(@:.o=.d))
endef

###############################################################################
## Commands to compile a C file.
###############################################################################

define transform-c-to-o
$(call print-banner1,"$(PRIVATE_ARCH) C",$(PRIVATE_MODULE),$(call path-from-top,$<))
$(call check-pwd-is-top-dir)
@mkdir -p $(dir $@)
$(Q)$(CCACHE) $(PRIVATE_CC) \
	$(call normalize-c-includes-rel,$(PRIVATE_C_INCLUDES)) \
	$(call normalize-system-c-includes-rel,$(TARGET_GLOBAL_C_INCLUDES)) \
	$(TARGET_GLOBAL_CFLAGS) $(WARNINGS_CFLAGS) \
	$(TARGET_GLOBAL_CFLAGS_$(PRIVATE_COMPILER_FLAVOUR)) \
	$(WARNINGS_CFLAGS_$(PRIVATE_COMPILER_FLAVOUR)) \
	$(TARGET_GLOBAL_CFLAGS_$(PRIVATE_ARCH)) \
	$(TARGET_GLOBAL_CFLAGS_$(PRIVATE_ARCH)_$(PRIVATE_COMPILER_FLAVOUR)) \
	$(PRIVATE_CFLAGS) \
	-c -MMD -MP -MF $(@:.o=.d) -MT $@ -o $@ \
	$(call path-from-top,$<)
$(call fix-deps-file,$(@:.o=.d))
endef

 ###############################################################################
## Commands to compile a Objective-C file.
###############################################################################

define transform-m-to-o
$(call print-banner1,"$(PRIVATE_ARCH) OBJC",$(PRIVATE_MODULE),$(call path-from-top,$<))
$(call check-pwd-is-top-dir)
@mkdir -p $(dir $@)
$(Q)$(CCACHE) $(PRIVATE_CC) \
	$(call normalize-c-includes-rel,$(PRIVATE_C_INCLUDES)) \
	$(call normalize-system-c-includes-rel,$(TARGET_GLOBAL_C_INCLUDES)) \
	$(TARGET_GLOBAL_CFLAGS) $(WARNINGS_CFLAGS) \
	$(TARGET_GLOBAL_CFLAGS_$(PRIVATE_COMPILER_FLAVOUR)) \
	$(WARNINGS_CFLAGS_$(PRIVATE_COMPILER_FLAVOUR)) \
	$(TARGET_GLOBAL_CFLAGS_$(PRIVATE_ARCH)) \
	$(TARGET_GLOBAL_CFLAGS_$(PRIVATE_ARCH)_$(PRIVATE_COMPILER_FLAVOUR)) \
	$(TARGET_GLOBAL_OBJCFLAGS) \
	$(PRIVATE_CFLAGS) $(PRIVATE_OBJCFLAGS) \
	-c -MMD -MP -MF $(@:.o=.d) -MT $@ -o $@ \
	$(call path-from-top,$<)
	$(call fix-deps-file,$(@:.o=.d))
endef

###############################################################################
## Commands to compile a S file.
###############################################################################

define transform-s-to-o
$(call print-banner1,"Asm",$(PRIVATE_MODULE),$(call path-from-top,$<))
$(call check-pwd-is-top-dir)
@mkdir -p $(dir $@)
$(Q)$(CCACHE) $(PRIVATE_CC) \
	$(call normalize-c-includes-rel,$(PRIVATE_C_INCLUDES)) \
	$(call normalize-system-c-includes-rel,$(TARGET_GLOBAL_C_INCLUDES)) \
	$(TARGET_GLOBAL_ASFLAGS) \
	$(TARGET_GLOBAL_CFLAGS) $(WARNINGS_CFLAGS) \
	$(TARGET_GLOBAL_CFLAGS_$(PRIVATE_COMPILER_FLAVOUR)) \
	$(WARNINGS_CFLAGS_$(PRIVATE_COMPILER_FLAVOUR)) \
	$(TARGET_GLOBAL_CFLAGS_$(PRIVATE_ARCH)) \
	$(TARGET_GLOBAL_CFLAGS_$(PRIVATE_ARCH)_$(PRIVATE_COMPILER_FLAVOUR)) \
	$(PRIVATE_ASFLAGS) \
	$(PRIVATE_CFLAGS) \
	-c -MMD -MP -MF $(@:.o=.d) -MT $@ -o $@ \
	$(call path-from-top,$<)
$(call fix-deps-file,$(@:.o=.d))
endef

###############################################################################
## Commands to compile vala files.
###############################################################################
define transform-vala-to-c
$(call print-banner1,"Valac",$(PRIVATE_MODULE),$(call path-from-top,$(PRIVATE_VALA_SOURCES)))
$(call check-pwd-is-top-dir)
$(Q) $(HOST_OUT_STAGING)/usr/bin/valac \
	$(TARGET_GLOBAL_VALAFLAGS) \
	$(PRIVATE_VALAFLAGS) \
	-C -d $(PRIVATE_VALA_OUT_DIR) -b $(PRIVATE_PATH) \
	--deps $(PRIVATE_VALA_DEPS_FILE) \
	$(PRIVATE_VALA_SOURCES)
endef

###############################################################################
## Commands to compile a cu file (cuda).
###############################################################################
define transform-cu-to-o
$(call print-banner1,"Cuda",$(PRIVATE_MODULE),$(call path-from-top,$<))
$(call check-pwd-is-top-dir)
@mkdir -p $(dir $@)
$(if $(TARGET_NVCC),$(empty),@echo "TARGET_NVCC is not defined"; exit 1)
$(Q) $(TARGET_NVCC) \
	$(call normalize-c-includes-rel,$(PRIVATE_C_INCLUDES)) \
	$(call normalize-system-c-includes-rel,$(TARGET_GLOBAL_C_INCLUDES)) \
	$(TARGET_GLOBAL_NVCFLAGS) \
	$(PRIVATE_NVCFLAGS) \
	-ccbin $(TARGET_CC) -c -o $@ \
	$(call path-from-top,$<)
$(call fix-deps-file,$(@:.o=.d))
endef

###############################################################################
## Commands for running ar.
###############################################################################

# Explicitly delete the archive first so that ar doesn't
# try to add to an existing archive.
define transform-o-to-static-lib
@mkdir -p $(dir $@)
$(call print-banner2,"StaticLib",$(PRIVATE_MODULE),$(call path-from-top,$@))
$(call check-pwd-is-top-dir)
@rm -f $@
$(Q)$(PRIVATE_AR) $(TARGET_GLOBAL_ARFLAGS) $(PRIVATE_ARFLAGS) $@ $(PRIVATE_ALL_OBJECTS)
endef

###############################################################################
## Commands to link a shared library.
###############################################################################

ifeq ("$(TARGET_OS)","darwin")

define transform-o-to-shared-lib
@mkdir -p $(dir $@)
$(call print-banner2,"SharedLib",$(PRIVATE_MODULE),$(call path-from-top,$@))
$(call check-pwd-is-top-dir)
$(Q)$(PRIVATE_CXX) \
	$(TARGET_GLOBAL_LDFLAGS_SHARED) \
	$(TARGET_GLOBAL_LDFLAGS_$(PRIVATE_COMPILER_FLAVOUR)) \
	$(if $(call streq,$(USE_LINK_MAP_FILE),1),-Wl$(comma)-map$(comma)$(basename $@).map) \
	-shared \
	-Wl,-dead_strip \
	-Wl,-install_name,$(TARGET_OUT_STAGING)/$(TARGET_DEFAULT_LIB_DESTDIR)/$(notdir $@) \
	$(PRIVATE_LDFLAGS) \
	$(PRIVATE_ALL_OBJECTS) \
	$(call link-hook,$(PRIVATE_MODULE),$@, \
		$(PRIVATE_ALL_OBJECTS) \
		$(PRIVATE_ALL_STATIC_LIBRARIES) \
		$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
	$(foreach __lib, $(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES), -force_load $(__lib)) \
	$(PRIVATE_ALL_STATIC_LIBRARIES) \
	$(PRIVATE_ALL_SHARED_LIBRARIES) \
	-o $@ \
	$(PRIVATE_LDLIBS) \
	$(TARGET_GLOBAL_LDLIBS_SHARED)
endef

else # !eq("$(TARGET_OS)","darwin")

define transform-o-to-shared-lib
@mkdir -p $(dir $@)
$(call print-banner2,"SharedLib",$(PRIVATE_MODULE),$(call path-from-top,$@))
$(call check-pwd-is-top-dir)
$(Q)$(PRIVATE_CXX) \
	$(TARGET_GLOBAL_LDFLAGS_SHARED) \
	$(TARGET_GLOBAL_LDFLAGS_$(PRIVATE_COMPILER_FLAVOUR)) \
	$(if $(call streq,$(USE_LINK_MAP_FILE),1),-Wl$(comma)-Map$(comma)$(basename $@).map) \
	-shared \
	-Wl,-soname -Wl,$(notdir $@) \
	-Wl,--no-undefined \
	-Wl,--gc-sections \
	-Wl,--as-needed \
	$(PRIVATE_LDFLAGS) \
	$(PRIVATE_ALL_OBJECTS) \
	$(call link-hook,$(PRIVATE_MODULE),$@, \
		$(PRIVATE_ALL_OBJECTS) \
		$(PRIVATE_ALL_STATIC_LIBRARIES) \
		$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
	-Wl,--whole-archive \
	$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES) \
	-Wl,--no-whole-archive \
	$(PRIVATE_ALL_STATIC_LIBRARIES) \
	$(PRIVATE_ALL_SHARED_LIBRARIES) \
	-o $@ \
	$(PRIVATE_LDLIBS) \
	$(TARGET_GLOBAL_LDLIBS_SHARED)
endef

endif

###############################################################################
## Commands to link an executable.
###############################################################################

ifeq ("$(TARGET_OS)","darwin")

define transform-o-to-executable
@mkdir -p $(dir $@)
$(call print-banner2,"Executable",$(PRIVATE_MODULE),$(call path-from-top,$@))
$(call check-pwd-is-top-dir)
$(Q)$(PRIVATE_CXX) \
	$(TARGET_GLOBAL_LDFLAGS) \
	$(TARGET_GLOBAL_LDFLAGS_$(PRIVATE_COMPILER_FLAVOUR)) \
	$(if $(call streq,$(USE_LINK_MAP_FILE),1),-Wl$(comma)-map$(comma)$(basename $@).map) \
	-Wl,-dead_strip \
	$(PRIVATE_LDFLAGS) \
	$(PRIVATE_ALL_OBJECTS) \
	$(call link-hook,$(PRIVATE_MODULE),$@, \
		$(PRIVATE_ALL_OBJECTS) \
		$(PRIVATE_ALL_STATIC_LIBRARIES) \
		$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
	$(foreach __lib, $(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES), -force_load $(__lib)) \
	$(PRIVATE_ALL_STATIC_LIBRARIES) \
	$(PRIVATE_ALL_SHARED_LIBRARIES) \
	-o $@ \
	$(PRIVATE_LDLIBS) \
	$(TARGET_GLOBAL_LDLIBS)
endef

else # !eq("$(TARGET_OS)","darwin")

define transform-o-to-executable
@mkdir -p $(dir $@)
$(call print-banner2,"Executable",$(PRIVATE_MODULE),$(call path-from-top,$@))
$(call check-pwd-is-top-dir)
$(Q)$(PRIVATE_CXX) \
	$(TARGET_GLOBAL_LDFLAGS) \
	$(TARGET_GLOBAL_LDFLAGS_$(PRIVATE_COMPILER_FLAVOUR)) \
	$(if $(call streq,$(USE_LINK_MAP_FILE),1),-Wl$(comma)-Map$(comma)$(basename $@).map) \
	-Wl,--gc-sections \
	-Wl,--as-needed \
	$(PRIVATE_LDFLAGS) \
	$(PRIVATE_ALL_OBJECTS) \
	$(call link-hook,$(PRIVATE_MODULE),$@, \
		$(PRIVATE_ALL_OBJECTS) \
		$(PRIVATE_ALL_STATIC_LIBRARIES) \
		$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES)) \
	-Wl,--whole-archive \
	$(PRIVATE_ALL_WHOLE_STATIC_LIBRARIES) \
	-Wl,--no-whole-archive \
	$(PRIVATE_ALL_STATIC_LIBRARIES) \
	$(PRIVATE_ALL_SHARED_LIBRARIES) \
	-o $@ \
	$(PRIVATE_LDLIBS) \
	$(TARGET_GLOBAL_LDLIBS)
endef

endif
