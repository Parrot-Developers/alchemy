###############################################################################
## @file classes/BINARY/rules.mk
## @author Y.M. Morgan
## @date 2016/03/20
##
## Rules for BINARY modules.
###############################################################################

# Prepend some directories in include list
LOCAL_C_INCLUDES := $(_module_build_dir) $(LOCAL_PATH) $(LOCAL_C_INCLUDES)

# TODO : remove this when all libraries have removed their dependencies toward
# config.h and autoconf.h
# force unsigned char always (default on arm, but not on PC_Linux)
ifneq ("$(strip $(LOCAL_PBUILD_HOOK))","")
  LOCAL_C_INCLUDES += $(BUILD_SYSTEM)/pbuild-hook
  LOCAL_CFLAGS += -funsigned-char
endif

# Sub-directory inside module build directory where object files will be put
obj_subdir := obj

# Handle atom.mk that declare source files in a directory that is not a direct
# child of LOCAL_PATH
#
# Using additional level in obj_subdir makes sure that object files will stay
# in 'obj' subdir...
#
# Up until now ../ was working BUT ../../ was definitely WRONG so print a
# message for them.
# ../../.. are not checked (will be treated as ../../)
#
$(if $(filter ../%,$(LOCAL_SRC_FILES)), \
	$(if $(filter ../../%,$(LOCAL_SRC_FILES)), \
		$(info $(LOCAL_PATH): $(LOCAL_MODULE) uses ../../ in sources files) \
		$(eval obj_subdir := $(obj_subdir)/dotdot/dotdot) \
		, \
		$(eval obj_subdir := $(obj_subdir)/dotdot) \
	) \
)

obj_dir := $(_module_build_dir)/$(obj_subdir)

###############################################################################
## List of sources, objects and libraries.
###############################################################################

all_gen_sources :=
all_objects :=
$(foreach __e,$(_binary_extensions), \
	$(eval $(__e)_sources := $(filter %.$(__e),$(LOCAL_SRC_FILES))) \
	$(eval $(__e)_objects := $(addprefix $(obj_dir)/,$($(__e)_sources:.$(__e)=.$(__e).o))) \
	$(eval gen_$(__e)_sources := $(filter %.$(__e),$(LOCAL_GENERATED_SRC_FILES))) \
	$(eval gen_$(__e)_objects := $(addprefix $(obj_dir)/,$(gen_$(__e)_sources:.$(__e)=.$(__e).o))) \
	$(eval all_gen_sources += $(gen_$(__e)_sources)) \
	$(eval all_objects += $($(__e)_objects) $(gen_$(__e)_objects)) \
)

ifeq ("$($(_mode_prefix)_OS)","windows")
  rc_sources := $(filter %.rc,$(LOCAL_SRC_FILES))
  rc_objects := $(addprefix $(obj_dir)/,$(rc_sources:.rc=.rc.o))
  gen_rc_sources := $(filter %.rc,$(LOCAL_GENERATED_SRC_FILES))
  gen_rc_objects := $(addprefix $(obj_dir)/,$(gen_rc_sources:.rc=.rc.o))
  all_gen_sources += $(gen_rc_sources)
  all_objects += $(rc_objects) $(gen_rc_objects)
else
  rc_sources :=
  rc_objects :=
  gen_rc_sources :=
  gen_rc_objects :=
endif

vala_sources := $(filter %.vala,$(LOCAL_SRC_FILES))
vala_c_sources := $(addprefix $(obj_dir)/,$(vala_sources:.vala=.c))
vala_objects := $(addprefix $(obj_dir)/,$(vala_sources:.vala=.c.o))

ifneq ("$(vala_objects)","")
  all_objects += $(vala_objects)
  vala_done_file := $(obj_dir)/vala.done
  vala_deps_file := $(obj_dir)/vala.d
  vala_header_file := $(_module_build_dir)/include/$(LOCAL_MODULE).vala.h
  vala_vapi_file := $(_module_build_dir)/include/$(LOCAL_MODULE).vapi
  vala_staging_c_sources_dir := $($(_mode_prefix)_OUT_STAGING)/$($(_mode_prefix)_ROOT_DESTDIR)/src/vala/$(LOCAL_MODULE)
  vala_staging_c_sources :=
  LOCAL_VALAFLAGS += --header=$(vala_header_file) --vapi=$(vala_vapi_file)
  LOCAL_C_INCLUDES += $(_module_build_dir)/include
else
  vala_done_file :=
  vala_deps_file :=
  vala_header_file :=
  vala_vapi_file :=
  vala_staging_c_sources_dir :=
  vala_staging_c_sources :=
endif

# User makefile is an internal dependencies
all_internal_depends := $(LOCAL_PATH)/$(USER_MAKEFILE_NAME)
all_internal_depends += $(all_autoconf)

# File with compilation flags to detect modifications
all_internal_depends += $(_module_build_dir)/$(LOCAL_MODULE).objects.flags

###############################################################################
## Actual rules.
###############################################################################

# $1 : extension
define _binary-rules-transform-to-o
ifneq ("$(strip $($1_objects))","")
$($1_objects): $(obj_dir)/%.$1.o: $(LOCAL_PATH)/%.$1
	$$(transform-$1-to-o)
ifneq ("$(skip_include_deps)","1")
-include $($1_objects:%.o=%.d)
endif
endif
endef

# $1 : extension
define _binary-rules-transform-gen-to-o
ifneq ("$(strip $(gen_$1_objects))","")
$(gen_$1_objects): $(obj_dir)/%.$1.o: $(_module_build_dir)/%.$1
	$$(transform-$1-to-o)
ifneq ("$(skip_include_deps)","1")
-include $(gen_$1_objects:%.o=%.d)
endif
endif
endef

$(foreach __e,$(_binary_extensions), \
	$(eval $(call _binary-rules-transform-to-o,$(__e))) \
	$(eval $(call _binary-rules-transform-gen-to-o,$(__e))) \
)

ifeq ("$($(_mode_prefix)_OS)","windows")
  $(eval $(call _binary-rules-transform-to-o,rc))
  $(eval $(call _binary-rules-transform-gen-to-o,rc))
endif

###############################################################################
# File with compilation flags
# The 'sed' command will remove leading spaces on each lines
# If we have make 4.0, create the file internally. This requires the 'mkdir' to
# be done in another rule to guarantee execution order
###############################################################################

_binary_objects_flags := $(_module_build_dir)/$(LOCAL_MODULE).objects.flags

$(_binary_objects_flags): .FORCE | $(_binary_objects_flags)-dir
ifeq ("$(MAKE_HAS_FILE_FUNC)","1")
	$(file > $@.tmp,$(_binary-get-objects-flags))
else
	@echo -e "$(call escape-echo,$(_binary-get-objects-flags))" > $@.tmp
endif
	@sed -i.bak -e 's/^ *//' $@.tmp && rm -f $@.tmp.bak
	$(call update-file-if-needed,$@,$@.tmp)

.PHONY: $(_binary_objects_flags)-dir
$(_binary_objects_flags)-dir:
	@mkdir -p $(dir $@)

$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(_binary_objects_flags)

###############################################################################
## vala rules (.vala files are in LOCAL_PATH, generated .c and .o are in build dir)
###############################################################################
ifneq ("$(strip $(vala_objects))","")

$(vala_objects): $(obj_dir)/%.c.o: $(obj_dir)/%.c
	$(transform-c-to-o)
$(vala_c_sources) $(vala_header_file) $(vala_vapi_file): $(vala_done_file)
	$(empty)
$(vala_done_file): $(addprefix $(LOCAL_PATH)/,$(vala_sources))
	@mkdir -p $(dir $@)
	@touch $@.tmp
	$(transform-vala-to-c)
	@mv -f $@.tmp $@
	@[ ! -f $(PRIVATE_VALA_DEPS_FILE) ] || sed \
		-e 's|$(PRIVATE_VALA_DEPS_FILE)|$@|g' \
		-i $(PRIVATE_VALA_DEPS_FILE)

# Copy generated source files in staging directory so it can be included in symbols
$(foreach __f,$(vala_c_sources), \
	$(eval __dst := $(patsubst $(obj_dir)/%,$(vala_staging_c_sources_dir)/%,$(__f))) \
	$(eval $(call copy-one-file,$(__f),$(__dst))) \
	$(eval vala_staging_c_sources += $(__dst)) \
)

# Do the copy before compiling (completely arbitrary)
$(vala_objects): $(vala_staging_c_sources)

$(vala_done_file): | $(filter-out $(vala_header_file) $(vala_vapi_file),$(all_prerequisites))
$(vala_done_file): $(all_internal_depends)

$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(vala_done_file)
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(vala_done_file).tmp
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(vala_staging_c_sources)

ifneq ("$(skip_include_deps)","1")
  -include $(vala_objects:%.o=%.d)
  -include $(vala_deps_file)
endif

endif

###############################################################################
## Precompiled headers.
###############################################################################

LOCAL_PRECOMPILED_FILE := $(strip $(LOCAL_PRECOMPILED_FILE))
ifneq ("$(LOCAL_PRECOMPILED_FILE)","")

gch_file := $(obj_dir)/$(LOCAL_PRECOMPILED_FILE).gch
LOCAL_C_INCLUDES := $(obj_dir) $(LOCAL_C_INCLUDES)

# All objects will depends on the precompiled file
$(all_objects): $(gch_file)

# Make sure all prerequisites files are generated first
# But do NOT force recompilation (order only)
ifneq ("$(all_prerequisites)","")
$(gch_file): | $(all_prerequisites)
endif

# Force recompilation if internal dependencies are changed
$(gch_file): $(all_internal_depends)

# Generate the precompiled file
$(gch_file): $(LOCAL_PATH)/$(LOCAL_PRECOMPILED_FILE)
	$(transform-h-to-gch)
ifneq ("$(skip_include_deps)","1")
-include $(gch_file:%.gch=%.d)
endif

# Clean precompiled header
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(gch_file)
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(gch_file:%.gch=%.d)

endif

###############################################################################
###############################################################################

# If local flavour is different than default one, remove default and add specific
ifeq ("$(_module_cc_flavour)","$($(_mode_prefix)_CC_FLAVOUR)")
  _binary_GLOBAL_CFLAGS := $($(_mode_prefix)_GLOBAL_CFLAGS)
  _binary_GLOBAL_CXXFLAGS := $($(_mode_prefix)_GLOBAL_CXXFLAGS)
  _binary_GLOBAL_LDFLAGS := $($(_mode_prefix)_GLOBAL_LDFLAGS)
else
$(foreach __f,CFLAGS CXXFLAGS LDFLAGS, \
	$(eval _binary_GLOBAL_$(__f) := \
		$(filter-out $($(_mode_prefix)_GLOBAL_$(__f)_$($(_mode_prefix)_CC_FLAVOUR)), \
			$($(_mode_prefix)_GLOBAL_$(__f)) \
		) \
		$($(_mode_prefix)_GLOBAL_$(__f)_$(_module_cc_flavour)) \
	) \
)
endif

###############################################################################
###############################################################################

# Make sure all prerequisites files are generated first
# But do NOT force recompilation (order only)
$(all_objects): | $(all_prerequisites) $(vala_header_file)

# Generated sources will depends on bootstrap and force
# recompilation in this case (NOT an order-only in here)
# Remove prerequisites from this list, to avoid circulat dependencies
$(filter-out $(all_prerequisites),$(addprefix $(_module_build_dir)/,$(all_gen_sources))): $(_module_bootstrapped_stamp_file)

# Force recompilation if internal dependencies are changed
$(all_objects): $(all_internal_depends)

# Clean objects
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(basename $(LOCAL_BUILD_MODULE)).map
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(all_objects)
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(all_objects:%.o=%.d)
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(vala_c_sources)
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(_module_build_dir)/*.rsp

$(LOCAL_TARGETS): PRIVATE_GLOBAL_CFLAGS := $(_binary_GLOBAL_CFLAGS)
$(LOCAL_TARGETS): PRIVATE_GLOBAL_CXXFLAGS := $(_binary_GLOBAL_CXXFLAGS)
$(LOCAL_TARGETS): PRIVATE_GLOBAL_LDFLAGS := $(_binary_GLOBAL_LDFLAGS)
$(LOCAL_TARGETS): PRIVATE_OBJ_DIR := $(obj_dir)
$(LOCAL_TARGETS): PRIVATE_C_INCLUDES := $(LOCAL_C_INCLUDES)
$(LOCAL_TARGETS): PRIVATE_ASFLAGS := $(LOCAL_ASFLAGS)
$(LOCAL_TARGETS): PRIVATE_CFLAGS := $(LOCAL_CFLAGS)
$(LOCAL_TARGETS): PRIVATE_CXXFLAGS := $(LOCAL_CXXFLAGS)
$(LOCAL_TARGETS): PRIVATE_OBJCFLAGS := $(LOCAL_OBJCFLAGS)
$(LOCAL_TARGETS): PRIVATE_OBJCXXFLAGS := $(LOCAL_OBJCXXFLAGS)
$(LOCAL_TARGETS): PRIVATE_FFLAGS := $(LOCAL_FFLAGS)
$(LOCAL_TARGETS): PRIVATE_VALAFLAGS := $(LOCAL_VALAFLAGS)
$(LOCAL_TARGETS): PRIVATE_VALA_SOURCES := $(addprefix $(LOCAL_PATH)/,$(vala_sources))
$(LOCAL_TARGETS): PRIVATE_VALA_OUT_DIR := $(obj_dir)
$(LOCAL_TARGETS): PRIVATE_VALA_DEPS_FILE := $(vala_deps_file)
$(LOCAL_TARGETS): PRIVATE_ARFLAGS := $(LOCAL_ARFLAGS)
$(LOCAL_TARGETS): PRIVATE_LDFLAGS := $(LOCAL_LDFLAGS)
$(LOCAL_TARGETS): PRIVATE_LDLIBS := $(LOCAL_LDLIBS)
$(LOCAL_TARGETS): PRIVATE_MODE_MSG := $(if $(_mode_host),Host )
$(LOCAL_TARGETS): PRIVATE_PBUILD_HOOK := $(LOCAL_PBUILD_HOOK)
$(LOCAL_TARGETS): PRIVATE_ALL_SHARED_LIBRARIES := $(all_shared_libs_filename)
$(LOCAL_TARGETS): PRIVATE_ALL_STATIC_LIBRARIES := $(all_static_libs_filename)
$(LOCAL_TARGETS): PRIVATE_ALL_WHOLE_STATIC_LIBRARIES := $(all_whole_static_libs_filename)
$(LOCAL_TARGETS): PRIVATE_ALL_OBJECTS := $(all_objects)
$(LOCAL_TARGETS): PRIVATE_WARNINGS_CFLAGS := $(WARNINGS_CFLAGS) $(WARNINGS_CFLAGS_$(_module_cc_flavour))
$(LOCAL_TARGETS): PRIVATE_WARNINGS_CXXFLAGS := $(WARNINGS_CXXFLAGS) $(WARNINGS_CXXFLAGS_$(_module_cc_flavour))

ifneq ("$(LOCAL_PRECOMPILED_FILE)","")
$(LOCAL_TARGETS): PRIVATE_PCH_INCLUDE := -include $(LOCAL_PRECOMPILED_FILE)
else
$(LOCAL_TARGETS): PRIVATE_PCH_INCLUDE :=
endif

ifeq ("$(W)","0")
ifneq ("$(strip $(vala_objects))","")
$(vala_objects): PRIVATE_CFLAGS += -Wno-missing-field-initializers
$(vala_objects): PRIVATE_CFLAGS += -Wno-missing-braces
endif
endif

###############################################################################
## Nvcc flags
## Remove from standard CFLAGS unsuported flags
## Fix some syntax difference (like for "-std" flag)
## Give filtered flags directly to compiler (with -Xcompiler prefix)
###############################################################################
ifeq ("$(LOCAL_HOST_MODULE)","")
__nvcflags-all := \
	$(TARGET_GLOBAL_CFLAGS) \
	$(LOCAL_CFLAGS) \
	$(TARGET_GLOBAL_CXXFLAGS) \
	$(LOCAL_CXXFLAGS)

# Always use gcc for cuda compilation, so remove clang specific flag if needed
ifeq ("$(_module_cc_flavour)","clang")
__nvcflags-all := $(filter-out $(TARGET_GLOBAL_CFLAGS)_clang,$(__nvcflags-all))
$(LOCAL_TARGETS): PRIVATE_NVCC_CC := $(TARGET_CROSS)gcc
else
$(LOCAL_TARGETS): PRIVATE_NVCC_CC := $(TARGET_CC)
endif

# collect -std* and --std* and keep only the latest like GCC
# local flags can override global ones
# also make sure it is named --std= not -std=
__nvcflags-std := $(filter -std=% --std=%, $(__nvcflags-all))
__nvcflags-all := $(filter-out $(__nvcflags-std),$(__nvcflags-all)) \
	$(subst -std,--std,$(lastword $(__nvcflags-std)))
__nvcflags-1 := $(filter-out -pthread -pipe -f% -m% -O% -W%, $(__nvcflags-all))
__nvcflags-2 := $(addprefix -Xcompiler ,$(filter -pthread -pipe -f% -m% -O%, $(__nvcflags-all)))
$(LOCAL_TARGETS): PRIVATE_NVCFLAGS := $(__nvcflags-1) $(__nvcflags-2)
endif

###############################################################################
###############################################################################

include $(BUILD_SYSTEM)/classes/GENERIC/rules.mk
