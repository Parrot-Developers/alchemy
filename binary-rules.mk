###############################################################################
## @file binary-rules.mk
## @author Y.M. Morgan
## @date 2011/05/14
##
## Generate rules for building an executable or library.
###############################################################################

# Prepend some directories in include list
LOCAL_C_INCLUDES := $(build_dir) $(LOCAL_PATH) $(LOCAL_C_INCLUDES)

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

###############################################################################
## List of sources, objects and libraries.
###############################################################################

cpp_sources := $(filter %.cpp,$(LOCAL_SRC_FILES))
cpp_objects := $(addprefix $(build_dir)/$(obj_subdir)/,$(cpp_sources:.cpp=.cpp.o))

cxx_sources := $(filter %.cxx,$(LOCAL_SRC_FILES))
cxx_objects := $(addprefix $(build_dir)/$(obj_subdir)/,$(cxx_sources:.cxx=.cxx.o))

cc_sources := $(filter %.cc,$(LOCAL_SRC_FILES))
cc_objects := $(addprefix $(build_dir)/$(obj_subdir)/,$(cc_sources:.cc=.cc.o))

c_sources := $(filter %.c,$(LOCAL_SRC_FILES))
c_objects := $(addprefix $(build_dir)/$(obj_subdir)/,$(c_sources:.c=.c.o))

cu_sources := $(filter %.cu,$(LOCAL_SRC_FILES))
cu_objects := $(addprefix $(build_dir)/$(obj_subdir)/,$(cu_sources:.cu=.cu.o))

m_sources := $(filter %.m,$(LOCAL_SRC_FILES))
m_objects := $(addprefix $(build_dir)/$(obj_subdir)/,$(m_sources:.m=.m.o))

s_sources := $(filter %.s,$(LOCAL_SRC_FILES))
s_objects := $(addprefix $(build_dir)/$(obj_subdir)/,$(s_sources:.s=.s.o))

S_sources := $(filter %.S,$(LOCAL_SRC_FILES))
S_objects := $(addprefix $(build_dir)/$(obj_subdir)/,$(S_sources:.S=.S.o))

gen_cpp_sources := $(filter %.cpp,$(LOCAL_GENERATED_SRC_FILES))
gen_cpp_objects := $(addprefix $(build_dir)/$(obj_subdir)/,$(gen_cpp_sources:.cpp=.cpp.o))

gen_cxx_sources := $(filter %.cxx,$(LOCAL_GENERATED_SRC_FILES))
gen_cxx_objects := $(addprefix $(build_dir)/$(obj_subdir)/,$(gen_cxx_sources:.cxx=.cxx.o))

gen_cc_sources := $(filter %.cc,$(LOCAL_GENERATED_SRC_FILES))
gen_cc_objects := $(addprefix $(build_dir)/$(obj_subdir)/,$(gen_cc_sources:.cc=.cc.o))

gen_c_sources := $(filter %.c,$(LOCAL_GENERATED_SRC_FILES))
gen_c_objects := $(addprefix $(build_dir)/$(obj_subdir)/,$(gen_c_sources:.c=.c.o))

gen_s_sources := $(filter %.s,$(LOCAL_GENERATED_SRC_FILES))
gen_s_objects := $(addprefix $(build_dir)/$(obj_subdir)/,$(gen_s_sources:.s=.s.o))

gen_S_sources := $(filter %.S,$(LOCAL_GENERATED_SRC_FILES))
gen_S_objects := $(addprefix $(build_dir)/$(obj_subdir)/,$(gen_S_sources:.S=.S.o))

vala_sources := $(filter %.vala,$(LOCAL_SRC_FILES))
vala_c_sources := $(addprefix $(build_dir)/$(obj_subdir)/,$(vala_sources:.vala=.c))
vala_objects := $(addprefix $(build_dir)/$(obj_subdir)/,$(vala_sources:.vala=.c.o))

ifneq ("$(vala_objects)","")
vala_done_file := $(build_dir)/$(obj_subdir)/vala.done
vala_deps_file := $(build_dir)/$(obj_subdir)/vala.d
vala_header_file := $(build_dir)/include/$(LOCAL_MODULE).vala.h
vala_vapi_file := $(build_dir)/include/$(LOCAL_MODULE).vapi
vala_staging_c_sources_dir := $(TARGET_OUT_STAGING)/usr/src/vala/$(LOCAL_MODULE)
vala_staging_c_sources :=
LOCAL_VALAFLAGS += \
	--header=$(vala_header_file) \
	--vapi=$(vala_vapi_file)
LOCAL_C_INCLUDES += \
	$(build_dir)/include
else
vala_done_file :=
vala_deps_file :=
vala_header_file :=
vala_vapi_file :=
vala_staging_c_sources_dir :=
vala_staging_c_sources :=
endif

all_gen_sources := \
	$(gen_cpp_sources) \
	$(gen_cxx_sources) \
	$(gen_cc_sources) \
	$(gen_c_sources) \
	$(gen_s_sources) \
	$(gen_S_sources)

all_objects := \
	$(cpp_objects) \
	$(cxx_objects) \
	$(cc_objects) \
	$(c_objects) \
	$(cu_objects) \
	$(m_objects) \
	$(s_objects) \
	$(S_objects) \
	$(gen_cpp_objects) \
	$(gen_cxx_objects) \
	$(gen_cc_objects) \
	$(gen_c_objects) \
	$(gen_s_objects) \
	$(gen_S_objects) \
	$(vala_objects)

# User makefile is an internal dependencies
all_internal_depends := $(LOCAL_PATH)/$(USER_MAKEFILE_NAME)
all_internal_depends += $(all_autoconf)

###############################################################################
## Actual rules.
###############################################################################

# cpp files
ifneq ("$(strip $(cpp_objects))","")
$(cpp_objects): $(build_dir)/$(obj_subdir)/%.cpp.o: $(LOCAL_PATH)/%.cpp
	$(transform-cpp-to-o)
ifneq ("$(skip_include_deps)","1")
-include $(cpp_objects:%.o=%.d)
endif
endif

# cxx files
ifneq ("$(strip $(cxx_objects))","")
$(cxx_objects): $(build_dir)/$(obj_subdir)/%.cxx.o: $(LOCAL_PATH)/%.cxx
	$(transform-cpp-to-o)
ifneq ("$(skip_include_deps)","1")
-include $(cxx_objects:%.o=%.d)
endif
endif

# cc files
ifneq ("$(strip $(cc_objects))","")
$(cc_objects): $(build_dir)/$(obj_subdir)/%.cc.o: $(LOCAL_PATH)/%.cc
	$(transform-cpp-to-o)
ifneq ("$(skip_include_deps)","1")
-include $(cc_objects:%.o=%.d)
endif
endif

# c files
ifneq ("$(strip $(c_objects))","")
$(c_objects): $(build_dir)/$(obj_subdir)/%.c.o: $(LOCAL_PATH)/%.c
	$(transform-c-to-o)
ifneq ("$(skip_include_deps)","1")
-include $(c_objects:%.o=%.d)
endif
endif

# cu files (cuda)
ifneq ("$(strip $(cu_objects))","")
$(cu_objects): $(build_dir)/$(obj_subdir)/%.cu.o: $(LOCAL_PATH)/%.cu
	$(transform-cu-to-o)
ifneq ("$(skip_include_deps)","1")
-include $(cu_objects:%.o=%.d)
endif
endif

# m files
ifneq ("$(strip $(m_objects))","")
$(m_objects): $(build_dir)/$(obj_subdir)/%.m.o: $(LOCAL_PATH)/%.m
	$(transform-m-to-o)
ifneq ("$(skip_include_deps)","1")
-include $(m_objects:%.o=%.d)
endif
endif

# s files
# There is NO dependency files for raw asm code...
ifneq ("$(strip $(s_objects))","")
$(s_objects): $(build_dir)/$(obj_subdir)/%.s.o: $(LOCAL_PATH)/%.s
	$(transform-s-to-o)
endif

# S files
# There is dependency files for asm code...
ifneq ("$(strip $(S_objects))","")
$(S_objects): $(build_dir)/$(obj_subdir)/%.S.o: $(LOCAL_PATH)/%.S
	$(transform-s-to-o)
ifneq ("$(skip_include_deps)","1")
-include $(S_objects:%.o=%.d)
endif
endif

# Generated cpp files
ifneq ("$(strip $(gen_cpp_objects))","")
$(gen_cpp_objects): $(build_dir)/$(obj_subdir)/%.cpp.o: $(build_dir)/%.cpp
	$(transform-cpp-to-o)
ifneq ("$(skip_include_deps)","1")
-include $(gen_cpp_objects:%.o=%.d)
endif
endif

# Generated cxx files
ifneq ("$(strip $(gen_cxx_objects))","")
$(gen_cxx_objects): $(build_dir)/$(obj_subdir)/%.cxx.o: $(build_dir)/%.cxx
	$(transform-cpp-to-o)
ifneq ("$(skip_include_deps)","1")
-include $(gen_cxx_objects:%.o=%.d)
endif
endif

# Generated cc files
ifneq ("$(strip $(gen_cc_objects))","")
$(gen_cc_objects): $(build_dir)/$(obj_subdir)/%.cc.o: $(build_dir)/%.cc
	$(transform-cpp-to-o)
ifneq ("$(skip_include_deps)","1")
-include $(gen_cc_objects:%.o=%.d)
endif
endif

# Generated c files
ifneq ("$(strip $(gen_c_objects))","")
$(gen_c_objects): $(build_dir)/$(obj_subdir)/%.c.o: $(build_dir)/%.c
	$(transform-c-to-o)
ifneq ("$(skip_include_deps)","1")
-include $(gen_c_objects:%.o=%.d)
endif
endif

# Generated s files
# There is NO dependency files for raw asm code...
ifneq ("$(strip $(gen_s_objects))","")
$(gen_s_objects): $(build_dir)/$(obj_subdir)/%.s.o: $(build_dir)/%.s
	$(transform-s-to-o)
endif

# Generated S files
# There is dependency files for asm code...
ifneq ("$(strip $(gen_S_objects))","")
$(gen_S_objects): $(build_dir)/$(obj_subdir)/%.S.o: $(build_dir)/%.S
	$(transform-s-to-o)
ifneq ("$(skip_include_deps)","1")
-include $(gen_S_objects:%.o=%.d)
endif
endif

# vala files (.vala files are in LOCAL_PATH, generated .c and .o are in build_dir)
ifneq ("$(strip $(vala_objects))","")
$(vala_objects): $(build_dir)/$(obj_subdir)/%.c.o: $(build_dir)/$(obj_subdir)/%.c
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
	$(eval __dst := $(patsubst $(build_dir)/$(obj_subdir)/%,$(vala_staging_c_sources_dir)/%,$(__f))) \
	$(eval $(call copy-one-file,$(__f),$(__dst))) \
	$(eval vala_staging_c_sources += $(__dst)) \
)

# Do the copy before compiling (completely arbitrary)
$(vala_objects): $(vala_staging_c_sources)

ifneq ("$(skip_include_deps)","1")
-include $(vala_objects:%.o=%.d)
-include $(vala_deps_file)
endif
endif

# Make sure all prerequisites files are generated first
# But do NOT force recompilation (order only)
ifneq ("$(all_prerequisites)","")
$(all_objects): | $(all_prerequisites) $(vala_header_file)
endif

# Generated sources will depends on unpaked archive (if needed) and force
# recompilation in this case (NOT an order-only in here)
ifneq ("$(LOCAL_ARCHIVE)","")
ifneq ("$(all_gen_sources)","")
$(addprefix $(build_dir)/,$(all_gen_sources)): $(unpacked_file)
endif
endif

# Force recompilation if internal dependencies are changed
$(all_objects): $(all_internal_depends)

# Clean objects
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(build_dir)/$(LOCAL_MODULE).map
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(build_dir)/$(LOCAL_MODULE_FILENAME).done
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(all_objects)
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(all_objects:%.o=%.d)
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(vala_c_sources)

# Vala stuff
ifneq ("$(vala_objects)","")
$(vala_done_file): | $(filter-out $(vala_header_file) $(vala_vapi_file),$(all_prerequisites))
$(vala_done_file): $(all_internal_depends)
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(vala_done_file)
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(vala_done_file).tmp
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(vala_staging_c_sources)
endif

###############################################################################
## Precompiled headers.
###############################################################################

LOCAL_PRECOMPILED_FILE := $(strip $(LOCAL_PRECOMPILED_FILE))
ifneq ("$(LOCAL_PRECOMPILED_FILE)","")

gch_file := $(build_dir)/$(obj_subdir)/$(LOCAL_PRECOMPILED_FILE).gch
LOCAL_C_INCLUDES := $(build_dir)/$(obj_subdir) $(LOCAL_C_INCLUDES)

# All objects will depends on the precompiled file
$(all_objects): $(gch_file)

# Make sure all prerequisites files are generated first
# But do NOT force recompilation (order only)
ifneq ("$(all_prerequisites)","")
$(gch_file): | $(all_prerequisites)
endif

# Force recompilation if internal dependencies are changes
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
## Rule-specific variable definitions.
###############################################################################

# Arch to display
arch :=
ifeq ("$(TARGET_ARCH)","arm")
  arch := $(LOCAL_ARM_MODE)
else
  arch := $(TARGET_ARCH)
endif

$(LOCAL_TARGETS): PRIVATE_ASFLAGS := $(LOCAL_ASFLAGS)
$(LOCAL_TARGETS): PRIVATE_CFLAGS := $(LOCAL_CFLAGS)
$(LOCAL_TARGETS): PRIVATE_C_INCLUDES := $(LOCAL_C_INCLUDES)
$(LOCAL_TARGETS): PRIVATE_CXXFLAGS := $(LOCAL_CXXFLAGS)
$(LOCAL_TARGETS): PRIVATE_OBJCFLAGS := $(LOCAL_OBJCFLAGS)
$(LOCAL_TARGETS): PRIVATE_VALAFLAGS := $(LOCAL_VALAFLAGS)
$(LOCAL_TARGETS): PRIVATE_VALA_SOURCES := $(addprefix $(LOCAL_PATH)/,$(vala_sources))
$(LOCAL_TARGETS): PRIVATE_VALA_OUT_DIR := $(build_dir)/$(obj_subdir)
$(LOCAL_TARGETS): PRIVATE_VALA_DEPS_FILE := $(vala_deps_file)
$(LOCAL_TARGETS): PRIVATE_ARFLAGS := $(LOCAL_ARFLAGS)
$(LOCAL_TARGETS): PRIVATE_LDFLAGS := $(LOCAL_LDFLAGS)
$(LOCAL_TARGETS): PRIVATE_LDLIBS := $(LOCAL_LDLIBS)
$(LOCAL_TARGETS): PRIVATE_ARCH := $(arch)
$(LOCAL_TARGETS): PRIVATE_PBUILD_HOOK := $(LOCAL_PBUILD_HOOK)
$(LOCAL_TARGETS): PRIVATE_ALL_SHARED_LIBRARIES := $(all_shared_libs_filename)
$(LOCAL_TARGETS): PRIVATE_ALL_STATIC_LIBRARIES := $(all_static_libs_filename)
$(LOCAL_TARGETS): PRIVATE_ALL_WHOLE_STATIC_LIBRARIES := $(all_whole_static_libs_filename)
$(LOCAL_TARGETS): PRIVATE_ALL_OBJECTS := $(all_objects)

ifneq ("$(LOCAL_PRECOMPILED_FILE)","")
$(LOCAL_TARGETS): PRIVATE_PCH_INCLUDE := -include $(LOCAL_PRECOMPILED_FILE)
else
$(LOCAL_TARGETS): PRIVATE_PCH_INCLUDE :=
endif

# Nvcc flags
# Remove from standard CFLAGS unsuported flags
# Give filtered flags directly to compiler (with -Xcompiler prefix)
__nvcflags-all := $(TARGET_GLOBAL_CFLAGS) $(TARGET_GLOBAL_CFLAGS_$(TARGET_ARCH)) $(LOCAL_CFLAGS)
__nvcflags-1 := $(filter-out -pthread -pipe -f% -m% -O%, $(__nvcflags-all))
__nvcflags-2 := $(addprefix -Xcompiler ,$(filter -pthread -pipe -f% -m% -O%, $(__nvcflags-all)))
$(LOCAL_TARGETS): PRIVATE_NVCFLAGS := $(__nvcflags-1) $(__nvcflags-2)

ifeq ("$(W)","0")
ifneq ("$(strip $(vala_objects))","")
$(vala_objects): PRIVATE_CFLAGS += -Wno-missing-field-initializers
$(vala_objects): PRIVATE_CFLAGS += -Wno-missing-braces
endif
endif
