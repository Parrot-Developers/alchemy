###############################################################################
## @file module.mk
## @author Y.M. Morgan
## @date 2012/04/17
##
## Build a module.
###############################################################################

# Bring back all LOCAL_XXX variables defined by LOCAL_MODULE
$(call module-restore-locals,$(LOCAL_MODULE))

ifneq ("$(V)","0")
$(info Generating rules for $(LOCAL_MODULE))
endif

# Make sure config is loaded
$(call load-config)

# This will print a warning if this module misses a custom macro
$(call check-custom-macro,$(LOCAL_MODULE))

# Do we need to copy build module to staging/final dir
copy_to_staging := 0
copy_to_final := 0

# Host/Target module customization
# Prefix is used for variable like TARGET_xxx or LOCAL_xxx
# Suffix is for macros.
ifneq ("$(LOCAL_HOST_MODULE)","")
  mode_host := $(true)
  mode_prefix := HOST_
  mode_suffix := -host
else
  mode_prefix := TARGET_
  mode_suffix :=
  mode_host :=
endif

# Build directory
build_dir := $(call module-get-build-dir,$(LOCAL_MODULE))

# Full path to build module
LOCAL_BUILD_MODULE := $(call module-get-build-filename,$(LOCAL_MODULE))

# Full path to staging module
LOCAL_STAGING_MODULE := $(call module-get-staging-filename,$(LOCAL_MODULE))

ifeq ("$(LOCAL_MODULE_CLASS)","LIBRARY")
LOCAL_BUILD_MODULE_STATIC := $(LOCAL_BUILD_MODULE:$(TARGET_SHARED_LIB_SUFFIX)=$(TARGET_STATIC_LIB_SUFFIX))
LOCAL_STAGING_MODULE_STATIC := $(LOCAL_STAGING_MODULE:$(TARGET_SHARED_LIB_SUFFIX)=$(TARGET_STATIC_LIB_SUFFIX))
endif

# Assemble the list of targets to create PRIVATE_ variables for.
LOCAL_TARGETS := \
	$(LOCAL_BUILD_MODULE) \
	$(LOCAL_CUSTOM_TARGETS) \
	$(LOCAL_MODULE) \
	$(LOCAL_MODULE)-clean \
	$(LOCAL_MODULE)-dirclean \
	$(LOCAL_MODULE)-path

ifneq ("$(value LOCAL_CMD_PRE_INSTALL)","")
preinstall_file := $(build_dir)/$(LOCAL_MODULE).preinstall
LOCAL_TARGETS += $(preinstall_file)
endif

###############################################################################
## ARM specific checks.
###############################################################################
ifeq ("$(mode_host)","")
ifeq ("$(TARGET_ARCH)","arm")

# Make sure LOCAL_ARM_MODE is valid
# If not set, use default mode
LOCAL_ARM_MODE := $(strip $(LOCAL_ARM_MODE))
ifeq ("$(LOCAL_ARM_MODE)","")
  LOCAL_ARM_MODE := $(TARGET_DEFAULT_ARM_MODE)
endif

ifneq ("$(LOCAL_ARM_MODE)","arm")
ifneq ("$(LOCAL_ARM_MODE)","thumb")
  $(error $(LOCAL_PATH): LOCAL_ARM_MODE is not valid : $(LOCAL_ARM_MODE))
endif
endif

# If default mode is not thumb, do not allow thumb, so the only practical use of
# this variable is to allow arm if default is thumb, not the other way around
ifneq ("$(TARGET_DEFAULT_ARM_MODE)","thumb")
  LOCAL_ARM_MODE := $(TARGET_DEFAULT_ARM_MODE)
endif

# Check that -marm or -mthumb is not forced in compilation flags
check-flags-arm-mode := -marm -mthumb
check-flags-arm-mode-message := please use LOCAL_ARM_MODE
$(call check-flags,LOCAL_CFLAGS,$(check-flags-arm-mode),$(check-flags-arm-mode-message))
$(call check-flags,LOCAL_CXXFLAGS,$(check-flags-arm-mode),$(check-flags-arm-mode-message))
$(call check-flags,LOCAL_EXPORT_CFLAGS,$(check-flags-arm-mode),$(check-flags-arm-mode-message))
$(call check-flags,LOCAL_EXPORT_CXXFLAGS,$(check-flags-arm-mode),$(check-flags-arm-mode-message))

endif # ifeq ("$(TARGET_ARCH)","arm")
endif # ifeq ("$(mode_host)","")

###############################################################################
## Generic checks.
###############################################################################

# Do not put -O0 in flags, use debug setup makefile
check-flags-debug := -O0
check-flags-debug-message := please use custom $(debug-setup-makefile) in top dir
$(call check-flags,LOCAL_CFLAGS,$(check-flags-debug),$(check-flags-debug-message))
$(call check-flags,LOCAL_CXXFLAGS,$(check-flags-debug),$(check-flags-debug-message))
$(call check-flags,LOCAL_EXPORT_CFLAGS,$(check-flags-debug),$(check-flags-debug-message))
$(call check-flags,LOCAL_EXPORT_CXXFLAGS,$(check-flags-debug),$(check-flags-debug-message))

# Forbid module to tweak architecture/cpu flags
# They shall come from alchemy or product in TARGET_XXX variables
check-flags-arch-cpu := -march=% -mcpu=% -mtune=% -mfloat-abi=%
check-flags-arch-cpu-message := please let alchemy or product determine arch/cpu flags

# Unfortunately, there is one use case where a module overwrites the -mfpu=
# due to a bug in 2012 toolchain
ifeq ("$(call str-starts-with,$(TARGET_CC_PATH),/opt/arm-2012.03)","")
  check-flags-arch-cpu += -mfpu=%
endif

$(call check-flags,LOCAL_CFLAGS,$(check-flags-arch-cpu),$(check-flags-arch-cpu-message))
$(call check-flags,LOCAL_CXXFLAGS,$(check-flags-arch-cpu),$(check-flags-arch-cpu-message))
$(call check-flags,LOCAL_EXPORT_CFLAGS,$(check-flags-arch-cpu),$(check-flags-arch-cpu-message))
$(call check-flags,LOCAL_EXPORT_CXXFLAGS,$(check-flags-arch-cpu),$(check-flags-arch-cpu-message))

###############################################################################
## Local Toolchain.
###############################################################################

module_cc := $(TARGET_CC)
module_cxx := $(TARGET_CXX)
module_as := $(TARGET_AS)
module_ar := $(TARGET_AR)
module_ld := $(TARGET_LD)
module_nm := $(TARGET_NM)
module_strip := $(TARGET_STRIP)
module_cpp := $(TARGET_CPP)
module_ranlib := $(TARGET_RANLIB)
module_objcopy := $(TARGET_OBJCOPY)
module_objdump := $(TARGET_OBJDUMP)

ifeq ("$(USE_CLANG)","1")
module_compiler_flavour := clang
else ifeq ("$(LOCAL_USE_CLANG)","1")
module_compiler_flavour := clang
else
module_compiler_flavour := gcc
endif

ifeq ("$(LOCAL_USE_CLANG)","1")
ifneq ("$(USE_CLANG)","1")
  ifeq ("$(LOCAL_CLANG_PATH)","")
    LOCAL_CLANG_PATH := $(HOST_OUT_STAGING)/usr/bin
  endif
  module_cc := $(LOCAL_CLANG_PATH)/clang
  module_cxx := $(LOCAL_CLANG_PATH)/clang++
  ifneq ("$(TARGET_ARCH)","arm")
    module_as := $(LOCAL_CLANG_PATH)/llvm-as
    module_ar := ar
    module_ld := $(LOCAL_CLANG_PATH)/llvm-ld
    module_nm := $(LOCAL_CLANG_PATH)/llvm-nm
    module_strip := strip
    module_cpp := cpp
    module_ranlib := $(LOCAL_CLANG_PATH)/llvm-ranlib
    module_objcopy := objcopy
    module_objdump := $(LOCAL_CLANG_PATH)/llvm-objdump
  endif
endif
endif

###############################################################################
## Dependencies.
###############################################################################

# Get all modules we depend on (fully recursive)
all_depends := $(call module-get-all-depends,$(LOCAL_MODULE))

# Get libraries used by us and static libraries
all_external_libs := \
	$(call module-get-static-depends,$(LOCAL_MODULE),EXTERNAL_LIBRARIES)
all_static_libs := \
	$(call module-get-static-depends,$(LOCAL_MODULE),STATIC_LIBRARIES)
all_whole_static_libs := \
	$(call module-get-static-depends,$(LOCAL_MODULE),WHOLE_STATIC_LIBRARIES)
all_shared_libs := \
	$(call module-get-static-depends,$(LOCAL_MODULE),SHARED_LIBRARIES)

# List of our dependencies and from static (recursive on static libs)
all_libs := \
	$(all_external_libs) \
	$(all_static_libs) \
	$(all_whole_static_libs) \
	$(all_shared_libs)

# Path of previous variables

all_depends_build_filename := \
	$(foreach __lib,$(all_depends), \
		$(call module-get-build-filename,$(__lib)))

# We use staging dir for linking static/shared libs
# For generic library, force retrieving static version if needed

all_static_libs_filename := \
	$(foreach __lib,$(all_static_libs), \
		$(eval __class := $(__modules.$(__lib).MODULE_CLASS)) \
		$(eval __fn := $(call module-get-staging-filename,$(__lib))) \
		$(if $(call streq,$(__class),LIBRARY), \
			$(__fn:$(TARGET_SHARED_LIB_SUFFIX)=$(TARGET_STATIC_LIB_SUFFIX)) \
			, \
			$(__fn) \
		) \
	)

all_whole_static_libs_filename := \
	$(foreach __lib,$(all_whole_static_libs), \
		$(eval __class := $(__modules.$(__lib).MODULE_CLASS)) \
		$(eval __fn := $(call module-get-staging-filename,$(__lib))) \
		$(if $(call streq,$(__class),LIBRARY), \
			$(__fn:$(TARGET_SHARED_LIB_SUFFIX)=$(TARGET_STATIC_LIB_SUFFIX)) \
			, \
			$(__fn) \
		) \
	)

all_shared_libs_filename := \
	$(foreach __lib,$(all_shared_libs), \
		$(call module-get-staging-filename,$(__lib)))

# all_link_libs_filenames is used for the dependencies at link time
all_link_libs_filenames := \
	$(all_static_libs_filename) \
	$(all_whole_static_libs_filename) \
	$(all_shared_libs_filename)

# Force pbuild hook if a static library needs it
$(foreach __mod,$(all_static_libs) $(all_whole_static_libs), \
	$(if $(__modules.$(__mod).PBUILD_HOOK), \
		$(eval LOCAL_PBUILD_HOOK := 1) \
	) \
)

###############################################################################
## Last revision used management
###############################################################################

ifneq ("$(USE_GIT_REV)","0")

# Include file with revision use for last build. It will define a variable
# if available.
revision_file := $(build_dir)/$(LOCAL_MODULE).revision
-include $(revision_file)

endif

###############################################################################
## Construct prerequisites.
###############################################################################

# List of all prerequisites (ours + dependencies)
all_prerequisites :=

# We need all external libraries as prerequisites.
all_prerequisites += \
	$(foreach __lib,$(all_depends), \
		$(if $(call is-module-external,$(__lib)), \
			$(call module-get-build-filename,$(__lib)) \
		) \
	)

# Remove our build module from the list of global deps to avoid circular chain
all_prerequisites += \
	$(filter-out $(LOCAL_BUILD_MODULE),$(TARGET_GLOBAL_PREREQUISITES)) \
	$(LOCAL_PREREQUISITES) \
	$(LOCAL_EXPORT_PREREQUISITES)

# Make sure autoconf.h file is generated
all_prerequisites += \
	$(call module-get-autoconf,$(LOCAL_MODULE))

# Make sure PRIVATE_XXX variables of prerequisites are correct
# Without this, the first module that needs the prerequisite will force its
# PRIVATE_XXX variables leading to 'interresting' results
LOCAL_TARGETS += \
	$(LOCAL_PREREQUISITES) \
	$(LOCAL_EXPORT_PREREQUISITES)

# Host modules required
# TODO: use staging filename for internal modules
all_prerequisites += \
	$(foreach __mod,$(LOCAL_DEPENDS_HOST_MODULES), \
		$(call module-get-build-filename,$(__mod)))

###############################################################################
## Import of dependencies.
##
## Note: LDLIBS only get ours and import from static dependencies.
## Other import are done on full dependency to make sure that include path
## are propagated even for shared library import.
##
## Note: external modules only import from internal modules, external module
## shall handle by themself import of external stuff (using pkg-config for example)
## we also don't add stuff exported by external module for their own compilation.
###############################################################################

# Get list of exported stuff by our dependencies
ifeq ("$(and $(call is-module-external,$(LOCAL_MODULE)),$(call strneq,$(LOCAL_MODULE_CLASS),QMAKE))","")
  # Internal module or QMAKE module
  imported_CFLAGS        := $(call module-get-listed-export,$(all_depends),CFLAGS)
  imported_CXXFLAGS      := $(call module-get-listed-export,$(all_depends),CXXFLAGS)
  imported_C_INCLUDES    := $(call module-get-listed-export,$(all_depends),C_INCLUDES)
  imported_LDLIBS        := $(call module-get-listed-export,$(all_libs),LDLIBS)

  imported_CFLAGS += $(LOCAL_EXPORT_CFLAGS)
  imported_CXXFLAGS += $(LOCAL_EXPORT_CXXFLAGS)
  imported_C_INCLUDES += $(LOCAL_EXPORT_C_INCLUDES)

  # Do not add exported libs for qmake, they generally refer to the module itself...
  # (only way for alchemy to know what do to with it)
  ifneq ("$(LOCAL_MODULE_CLASS)","QMAKE")
    imported_LDLIBS += $(LOCAL_EXPORT_LDLIBS)
  endif

else
  # External module, we only import from internal modules
  imported_CFLAGS        := $(call module-get-listed-export,$(call filter-get-internal-modules,$(all_depends)),CFLAGS)
  imported_CXXFLAGS      := $(call module-get-listed-export,$(call filter-get-internal-modules,$(all_depends)),CXXFLAGS)
  imported_C_INCLUDES    := $(call module-get-listed-export,$(call filter-get-internal-modules,$(all_depends)),C_INCLUDES)
  imported_LDLIBS        := $(call module-get-listed-export,$(call filter-get-internal-modules,$(all_libs)),LDLIBS)
endif

# Add includes of modules listed in LOCAL_DEPENDS_HEADERS
imported_C_INCLUDES += $(call module-get-listed-export,$(LOCAL_DEPENDS_HEADERS),C_INCLUDES)

# Import prerequisites (the one for this module are already in all_prerequisites)
imported_PREREQUISITES := $(call module-get-listed-export,$(all_depends),PREREQUISITES)
all_prerequisites += $(imported_PREREQUISITES)

# The imported/exported compiler flags are prepended to their LOCAL_XXXX value
# (this allows the module to override them).
LOCAL_CFLAGS     := $(strip $(imported_CFLAGS) $(LOCAL_CFLAGS))
LOCAL_CXXFLAGS   := $(strip $(imported_CXXFLAGS) $(LOCAL_CXXFLAGS))

# The imported/exported include directories are appended to their LOCAL_XXX value
# (this allows the module to override them)
LOCAL_C_INCLUDES := $(strip $(LOCAL_C_INCLUDES) $(imported_C_INCLUDES))

# Similarly, you want the imported/exported flags to appear _after_ the LOCAL_LDLIBS
# due to the way Unix linkers work (depending libraries must appear before
# dependees on final link command).
LOCAL_LDLIBS     := $(strip $(LOCAL_LDLIBS) $(imported_LDLIBS))

# Get all autoconf files that we depend on, don't forget to add ourself
# External modules only get internal ones. Mainly because we don't want to break
# build of external modules that already handle external dependencies correctly.
ifeq ("$(call is-module-external,$(LOCAL_MODULE))","")
all_autoconf := $(call module-get-listed-autoconf, \
	$(all_depends) $(LOCAL_MODULE))
else
all_autoconf := $(call module-get-listed-autoconf, \
	$(call filter-get-internal-modules,$(all_depends)) $(LOCAL_MODULE))
endif

# Force their inclusion (space after -include and before comma is important)
LOCAL_CFLAGS += $(addprefix -include ,$(all_autoconf))

# Notify that we build with dependencies
# External modules only get internal ones. Mainly because we don't want to break
# build of external modules that already handle external dependencies correctly.
ifeq ("$(and $(call is-module-external,$(LOCAL_MODULE)),$(call strneq,$(LOCAL_MODULE_CLASS),QMAKE))","")
LOCAL_CFLAGS += $(foreach __mod,$(all_depends), \
	-DBUILD_$(call module-get-define,$(__mod)))
LOCAL_VALAFLAGS += $(foreach __mod,$(call filter-get-internal-modules,$(all_depends)), \
	--define BUILD_$(call module-get-define,$(__mod)))
else
LOCAL_CFLAGS += $(foreach __mod,$(call filter-get-internal-modules,$(all_depends)), \
	-DBUILD_$(call module-get-define,$(__mod)))
endif

# Add debug flags at the end
$(call add-debug-flags)

# Code coverage flags (for internal modules only)
ifeq ("$(and $(call is-module-external,$(LOCAL_MODULE)),$(call strneq,$(LOCAL_MODULE_CLASS),QMAKE))","")
ifeq ("$(USE_COVERAGE)","1")
  LOCAL_CFLAGS  += -fprofile-arcs -ftest-coverage -O0 -D__COVERAGE__
  LOCAL_LDFLAGS += -fprofile-arcs -ftest-coverage
  LOCAL_LDFLAGS_SHARED += -fprofile-arcs -ftest-coverage
endif
endif

###############################################################################
## Determine flags that external modules will need to add manually.
## External modules (AUTOTOOLS, CMAKE) only have CFLAGS CXXFLAGS and LDFLAGS.
## Moreover CXXFLAGS does not inherit from CFLAGS so it must contains it.
###############################################################################

# Compilation flags
__external-add_ASFLAGS := $(LOCAL_ASFLAGS)
__external-add_CFLAGS := $(LOCAL_CFLAGS) $(call normalize-c-includes,$(LOCAL_C_INCLUDES))
__external-add_CXXFLAGS := $(__external-add_CFLAGS) $(LOCAL_CXXFLAGS)

# Linker flags
__external-add_LDFLAGS :=


# Whole static libraries
# As one unique -Wl option otherwise libtool make a terrible mess with it
# (it splits -Wl otions from -l options making encapsulation useless)
# With -l: to force using the given path
ifneq ("$(strip $(all_whole_static_libs_filename))","")
__external-add_LDFLAGS += -Wl,--whole-archive
$(foreach __lib,$(all_whole_static_libs_filename), \
	$(if $(filter lib%$(TARGET_STATIC_LIB_SUFFIX), $(notdir $(__lib))), \
	$(eval __external-add_LDFLAGS := $(__external-add_LDFLAGS),-l$(patsubst lib%$(TARGET_STATIC_LIB_SUFFIX),%,$(notdir $(__lib)))), \
	$(eval __external-add_LDFLAGS := $(__external-add_LDFLAGS),-l:$(notdir $(__lib)))) \
)
__external-add_LDFLAGS := $(__external-add_LDFLAGS),--no-whole-archive
endif

# Static libraries
# With -l: to force using the given path
# No comma separated list (like above or below !)
ifneq ("$(strip $(all_static_libs_filename))","")
$(foreach __lib,$(all_static_libs_filename), \
	$(if $(filter lib%$(TARGET_STATIC_LIB_SUFFIX), $(notdir $(__lib))), \
	$(eval __external-add_LDFLAGS := $(__external-add_LDFLAGS) -l$(patsubst lib%$(TARGET_STATIC_LIB_SUFFIX),%,$(notdir $(__lib)))), \
	$(eval __external-add_LDFLAGS := $(__external-add_LDFLAGS) -l:$(notdir $(__lib)))) \
)
endif

# Shared libraries
# As one unique -Wl option otherwise libtool make a terrible mess with it
# (it splits -Wl otions from -l options making encapsulation useless)
# With -l: to force using the given path
ifneq ("$(strip $(all_shared_libs_filename))","")
__external-add_LDFLAGS += -Wl
$(foreach __lib,$(all_shared_libs_filename), \
	$(if $(filter lib%$(TARGET_SHARED_LIB_SUFFIX), $(notdir $(__lib))), \
	$(eval __external-add_LDFLAGS := $(__external-add_LDFLAGS),-l$(patsubst lib%$(TARGET_SHARED_LIB_SUFFIX),%,$(notdir $(__lib)))), \
	$(eval __external-add_LDFLAGS := $(__external-add_LDFLAGS),-l:$(notdir $(__lib)))) \
)
endif

# Add local defined flags and libs
__external-add_LDFLAGS += $(LOCAL_LDFLAGS) $(LOCAL_LDLIBS)

###############################################################################
## Skip some stuff to improve scanning.
###############################################################################

# Skip parsing dependencies if requested
skip_include_deps := 0
ifneq ("$(SKIP_DEPS_AND_CHECKS)","0")
  skip_include_deps := 1
endif

# Skip external checks if requested
skip_ext_checks := 1
ifeq ("$(SKIP_EXT_DEPS_AND_CHECKS)","0")
  skip_ext_checks := 0
endif

# If we are explicitely building this module, do not skip external checks
ifneq ("$(call is-module-in-make-goals,$(LOCAL_MODULE))","")
  skip_ext_checks := 0
endif

# To not skip dep checks of QMake modules
ifeq ("$(LOCAL_MODULE_CLASS)","QMAKE")
  skip_ext_checks := 0
endif

# If revision of last build is not the same, do not skip external checks
# FIXME: modules dependending on this one will not be forced to be checked.
ifneq ("$(USE_GIT_REV)","0")
ifneq ("$(call module-check-revision-changed,$(LOCAL_MODULE))","")
  ifneq ("$(V)","0")
    $(info $(LOCAL_MODULE): revision has changed since last build)
  endif
  skip_ext_checks := 0
endif
endif

###############################################################################
## External checks : module built externaly may have other dependencies.
###############################################################################

# Update list of 'done' files with module file name
# Using sort ensures there is no duplicates in the list
ifeq ("$(patsubst %.done,1,$(LOCAL_MODULE_FILENAME))","1")
  LOCAL_DONE_FILES := $(sort $(LOCAL_DONE_FILES) $(LOCAL_MODULE_FILENAME))
endif

# Macro to create a module 'done' file
define create-done-file
@( \
	done_file=$(call module-get-build-filename,$@); \
	if [ ! -f "$${done_file}" ]; then \
		if [ "$(__modules.$@.check-done-file-created)" != "" ]; then \
			echo "warning: $(__modules.$@.MODULE_CLASS) module '$@' did not create $${done_file}"; \
		fi; \
		mkdir -p $$(dirname $${done_file}); \
		touch $${done_file}; \
	fi; \
)
endef

# Macro to delete one 'done' file
# $1 : file to delete
delete-one-done-file = \
	$(if $(wildcard $1), \
		$(if $(call strneq,$(V),0), \
			$(info Deleting $(call path-from-top,$1)) \
		) \
		$(shell rm -f $1) \
	)

# Macro to delete all 'done' files registered in module
delete-all-done-files = \
	$(foreach __f,$(LOCAL_DONE_FILES),\
		$(call delete-one-done-file, \
			$(call module-get-build-dir,$(LOCAL_MODULE))/$(__f) \
		) \
	)

# If not skipping checks of of module built externally, delete 'done' files
ifeq ("$(skip_ext_checks)","0")
$(delete-all-done-files)
endif

###############################################################################
## General rules.
###############################################################################

# Short hand to build module
.PHONY: $(LOCAL_MODULE)
$(LOCAL_MODULE): $(LOCAL_BUILD_MODULE)

# Add direct dependencies. Mainly used for copy to staging/final dir to get
# everything built for the module
$(LOCAL_MODULE): $(call module-get-depends,$(LOCAL_MODULE))

# Clean module
.PHONY: $(LOCAL_MODULE)-clean
$(LOCAL_MODULE)-clean: $(LOCAL_MODULE)-clean-common

# Common part, delete registered files and directories
# Note: the foreach generates a separate command for each file/dir thanks to
# the $(endl) macro that insert a new line during expansion.
.PHONY: $(LOCAL_MODULE)-clean-common
$(LOCAL_MODULE)-clean-common:
	@echo "Clean: $(PRIVATE_MODULE)"
	$(foreach __f,$(PRIVATE_CLEAN_FILES),$(Q)rm -f $(__f)$(endl))
	$(foreach __d,$(PRIVATE_CLEAN_DIRS),$(Q)rm -rf $(__d)$(endl))

# Clean + delete the build directory
.PHONY: $(LOCAL_MODULE)-dirclean
$(LOCAL_MODULE)-dirclean: $(LOCAL_MODULE)-clean
	$(Q)rm -rf $(PRIVATE_BUILD_DIR)
	+$(call macro-exec-cmd,CMD_POST_DIRCLEAN,empty)

# Display the path of the module
.PHONY: $(LOCAL_MODULE)-path
$(LOCAL_MODULE)-path:
	@echo "$(PRIVATE_MODULE): $(PRIVATE_PATH)"

# Generic library needs static version as well
ifeq ("$(LOCAL_MODULE_CLASS)","LIBRARY")
ifeq ("$(LOCAL_SDK)","")
$(LOCAL_MODULE): $(LOCAL_BUILD_MODULE_STATIC)
LOCAL_TARGETS += $(LOCAL_BUILD_MODULE_STATIC)
endif
endif

# If the user makefile is modified, this will trigger a check of the module
# Prebuilt modules migth not be defined in an user makefile so skip this for them
ifneq ("$(LOCAL_MODULE_CLASS)","PREBUILT")
$(LOCAL_BUILD_MODULE): $(LOCAL_PATH)/$(USER_MAKEFILE_NAME)
endif

ifneq ("$(USE_GIT_REV)","0")

# Generate the file containing the revision used in last build.
# Do not do that on a target with the name of the file to avoid reparsing
# everything when a change is made. Moreover, we want the file to be created
# AFTER module is built, not BEFORE (at time of inclusion of generated file).
$(LOCAL_MODULE): | $(LOCAL_MODULE)-gen-last-rev

.PHONY: $(LOCAL_MODULE)-gen-last-rev
$(LOCAL_MODULE)-gen-last-rev: PRIVATE_MODULE := $(LOCAL_MODULE)
$(LOCAL_MODULE)-gen-last-rev: PRIVATE_REV_FILE := $(revision_file)
$(LOCAL_MODULE)-gen-last-rev: $(LOCAL_BUILD_MODULE)
	@$(call generate-last-revision-file,$(PRIVATE_MODULE),$(PRIVATE_REV_FILE))

# Header to also generate, but as it can be included by source files, it shall
# be in prerequisites
revision_file_h := $(build_dir)/$(LOCAL_MODULE)-revision.h
all_prerequisites += $(revision_file_h)

# To be able to always have the correct value, use an order only dep to a
# generation rule that will create a temp file and update the real one only
# when needed. This way the header file is not updated unnecessarily and thus do
# not trigger unnecessary compilation rules.
# Empty command is to avoid a pattern matching rule to be used.
$(revision_file_h): | $(LOCAL_MODULE)-gen-rev-h
	$(empty)

.PHONY: $(LOCAL_MODULE)-gen-rev-h
$(LOCAL_MODULE)-gen-rev-h: PRIVATE_MODULE := $(LOCAL_MODULE)
$(LOCAL_MODULE)-gen-rev-h: PRIVATE_REV_FILE_H := $(revision_file_h)
$(LOCAL_MODULE)-gen-rev-h:
	@mkdir -p $(dir $(PRIVATE_REV_FILE_H))
	@( \
		var="$(call module-get-define,$(PRIVATE_MODULE))"; \
		val="$(call module-get-revision,$(PRIVATE_MODULE))"; \
		val2="$(call module-get-revision-describe,$(PRIVATE_MODULE))"; \
		echo "#define ALCHEMY_REVISION_$${var} \"$${val}\""; \
		echo "#define ALCHEMY_REVISION_DESCRIBE_$${var} \"$${val2}\""; \
	) > $(PRIVATE_REV_FILE_H).tmp
	@if [ ! -f $(PRIVATE_REV_FILE_H) ]; then \
		mv -f $(PRIVATE_REV_FILE_H).tmp $(PRIVATE_REV_FILE_H); \
	elif ! diff -q $(PRIVATE_REV_FILE_H).tmp $(PRIVATE_REV_FILE_H) &>/dev/null; then \
		mv -f $(PRIVATE_REV_FILE_H).tmp $(PRIVATE_REV_FILE_H); \
	else \
		rm -f $(PRIVATE_REV_FILE_H).tmp; \
	fi

endif

# This will force to recheck this module if one of its dependencies is changed.
$(LOCAL_BUILD_MODULE): $(all_depends_build_filename)
$(LOCAL_CUSTOM_TARGETS): $(all_depends_build_filename)

# This explicit rule avoids dependency error when the module has nothing to build
# (prebuilt, sdk, custom...)
$(LOCAL_BUILD_MODULE):

###############################################################################
## Rule-specific variable definitions.
###############################################################################

$(LOCAL_TARGETS): PRIVATE_COMPILER_FLAVOUR := $(module_compiler_flavour)
$(LOCAL_TARGETS): PRIVATE_CC := $(module_cc)
$(LOCAL_TARGETS): PRIVATE_CXX := $(module_cxx)
$(LOCAL_TARGETS): PRIVATE_AS := $(module_as)
$(LOCAL_TARGETS): PRIVATE_AR := $(module_ar)
$(LOCAL_TARGETS): PRIVATE_LD := $(module_ld)
$(LOCAL_TARGETS): PRIVATE_NM := $(module_nm)
$(LOCAL_TARGETS): PRIVATE_STRIP := $(module_strip)
$(LOCAL_TARGETS): PRIVATE_CPP := $(module_cpp)
$(LOCAL_TARGETS): PRIVATE_RANLIB := $(module_ranlib)
$(LOCAL_TARGETS): PRIVATE_OBJCOPY := $(module_objcopy)
$(LOCAL_TARGETS): PRIVATE_OBJDUMP := $(module_objdump)
$(LOCAL_TARGETS): PRIVATE_PATH := $(LOCAL_PATH)
$(LOCAL_TARGETS): PRIVATE_MODULE := $(LOCAL_MODULE)
$(LOCAL_TARGETS): PRIVATE_BUILD_DIR := $(build_dir)
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES := $(LOCAL_CLEAN_FILES) $(LOCAL_BUILD_MODULE)
$(LOCAL_TARGETS): PRIVATE_CLEAN_DIRS := $(LOCAL_CLEAN_DIRS)
$(LOCAL_TARGETS): PRIVATE_MODE := $(mode_prefix)
$(LOCAL_TARGETS): PRIVATE_REV_FILE := $(revision_file)
$(LOCAL_TARGETS): PRIVATE_REV_FILE_H := $(revision_file_h)

# This is for police hooks
$(LOCAL_TARGETS): export MODULE_NAME := $(LOCAL_MODULE)

###############################################################################
## Configuration file management.
###############################################################################

config_file := $(call __get-build-module-config,$(LOCAL_MODULE))
autoconf_file := $(call module-get-autoconf,$(LOCAL_MODULE))
ifneq ("$(autoconf_file)","")

# autoconf.h file depends on module config
$(autoconf_file): $(config_file)
	@$(call generate-autoconf-file,$<,$@)

# Don't forget to clean autoconf.h file
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(autoconf_file)

endif # ifneq ("$(autoconf_file)","")

###############################################################################
## Copy everything under LOCAL_PATH in build directory first.
###############################################################################

ifeq ("$(LOCAL_COPY_TO_BUILD_DIR)","1")

# All files under LOCAL_PATH
__copy-to-build-dir-src-files := $(shell find $(LOCAL_PATH) \
	-name '.git' -prune -o \
	-name '$(USER_MAKEFILE_NAME)' -prune \
	-o -not -type d -print)

# Where they wil be copied
__copy-to-build-dir-dst-dir := $(build_dir)
__copy-to-build-dir-dst-files := $(patsubst $(LOCAL_PATH)/%,$(__copy-to-build-dir-dst-dir)/%,$(__copy-to-build-dir-src-files))

# Add rule to copy them
$(foreach __f,$(__copy-to-build-dir-src-files), \
	$(eval $(call copy-one-file,$(__f),$(patsubst $(LOCAL_PATH)/%,$(__copy-to-build-dir-dst-dir)/%,$(__f)))) \
)

all_prerequisites += $(__copy-to-build-dir-dst-files)

endif

###############################################################################
## Archive extraction + patches.
## Do this step if there is no archive but there is a post unpack command.
## This is to handle cases where a pre-configure step is needed but no
## real archive to unpack. And because there is no pre-cmd variables at the
## moment.
###############################################################################
archive_file :=
unpacked_file :=
ifneq ("$(or $(LOCAL_ARCHIVE),$(value LOCAL_ARCHIVE_CMD_POST_UNPACK))","")

# Full path to archive file (can be empty if we only want post unpack command)
ifneq ("$(strip $(LOCAL_ARCHIVE))","")
  archive_file := $(LOCAL_PATH)/$(LOCAL_ARCHIVE)
endif

# Name of files indicating steps done
# Using version allow to switch without having some dependencies troubles
ifneq ("$(LOCAL_ARCHIVE_VERSION)","")
  unpacked_file := $(build_dir)/$(LOCAL_MODULE)-$(LOCAL_ARCHIVE_VERSION).unpacked
else
  unpacked_file := $(build_dir)/$(LOCAL_MODULE).unpacked
endif

# Where to unpack
unpack_dir := $(build_dir)

# Patches to apply
patches := $(strip $(LOCAL_ARCHIVE_PATCHES))

# Generated files to be compiled will also depends on 'unpacked_file' in
# binary-rules.mk
all_prerequisites += $(unpacked_file)

define __archive-default-unpack
	$(if $(call strneq,$(realpath $(PRIVATE_ARCHIVE_UNPACK_DIR)/$(PRIVATE_ARCHIVE_SUBDIR)),$(realpath $(PRIVATE_ARCHIVE_UNPACK_DIR))), \
		$(Q) rm -rf $(PRIVATE_ARCHIVE_UNPACK_DIR)/$(PRIVATE_ARCHIVE_SUBDIR))
	$(Q) $(if $(patsubst %.zip,,$(PRIVATE_ARCHIVE)), \
		tar -C $(PRIVATE_ARCHIVE_UNPACK_DIR) -xf $(PRIVATE_ARCHIVE), \
		unzip -oq -d $(PRIVATE_ARCHIVE_UNPACK_DIR) $(PRIVATE_ARCHIVE) \
	)
endef

define __archive-apply-patches
	$(Q) $(BUILD_SYSTEM)/scripts/apply-patches.sh \
		$(PRIVATE_ARCHIVE_UNPACK_DIR)/$(PRIVATE_ARCHIVE_SUBDIR) \
		$(PRIVATE_PATH) \
		$(PRIVATE_ARCHIVE_PATCHES)
endef

# Copy in build dir shall be done first
ifeq ("$(LOCAL_COPY_TO_BUILD_DIR)","1")
$(unpacked_file): | $(__copy-to-build-dir-dst-files)
endif

$(unpacked_file): $(archive_file) $(addprefix $(LOCAL_PATH)/,$(patches))
ifneq ("$(archive_file)","")
	$(call print-banner2,Archive,$(PRIVATE_MODULE),Unpacking $(call path-from-top,$<))
	@mkdir -p $(PRIVATE_ARCHIVE_UNPACK_DIR)
	+$(call macro-exec-cmd,ARCHIVE_CMD_UNPACK,__archive-default-unpack)
	+$(if $(PRIVATE_ARCHIVE_PATCHES),$(__archive-apply-patches))
	$(call copy-license-files,$(PRIVATE_PATH),$(PRIVATE_ARCHIVE_UNPACK_DIR)/$(PRIVATE_ARCHIVE_SUBDIR))
endif
	+$(call macro-exec-cmd,ARCHIVE_CMD_POST_UNPACK,empty)
	@mkdir -p $(dir $@)
	@touch $@

# Make sure unpack is done after copying files in build directory
ifeq ("$(LOCAL_COPY_TO_BUILD_DIR)","1")
$(unpacked_file): $(__copy-to-build-dir-dst-files)
endif

# Custom post unpack steps could need dependenciess to be built first
ifneq ("$(value LOCAL_ARCHIVE_CMD_POST_UNPACK)","")
$(unpacked_file): | $(all_depends_build_filename)
endif

$(LOCAL_TARGETS): PRIVATE_ARCHIVE := $(archive_file)
$(LOCAL_TARGETS): PRIVATE_ARCHIVE_UNPACK_DIR := $(unpack_dir)
$(LOCAL_TARGETS): PRIVATE_ARCHIVE_SUBDIR := $(LOCAL_ARCHIVE_SUBDIR)
$(LOCAL_TARGETS): PRIVATE_ARCHIVE_PATCHES := $(patches)

# With no archive file, force the post unpack step when sha1 is changed.
# This allows autotools bootstrap hacks to work better
ifeq ("$(archive_file)","")
ifneq ("$(USE_GIT_REV)","0")
ifneq ("$(call module-check-revision-changed,$(LOCAL_MODULE))","")
$(call delete-one-done-file,$(unpacked_file))
endif
endif
endif

endif

###############################################################################
## Documentation generation rules.
###############################################################################

.PHONY: $(LOCAL_MODULE)-doc

# Define target variables because we don't inherit from 'standard' targets
$(LOCAL_MODULE)-doc: PRIVATE_MODULE := $(LOCAL_MODULE)
$(LOCAL_MODULE)-doc: PRIVATE_PATH := $(LOCAL_PATH)
$(LOCAL_MODULE)-doc: PRIVATE_DESCRIPTION := $(LOCAL_DESCRIPTION)
$(LOCAL_MODULE)-doc: PRIVATE_DOC_DIR := $(TARGET_OUT_DOC)/$(LOCAL_MODULE)

ifneq ("$(LOCAL_DOXYFILE)","")

LOCAL_DOXYFILE := \
	$(if $(call is-path-absolute,$(LOCAL_DOXYFILE)), \
		$(LOCAL_DOXYFILE), \
		$(addprefix $(LOCAL_PATH)/,$(LOCAL_DOXYFILE)) \
	)

# If a doxyfile has been defined by the user, we use it
# Check if the input paths are absolute and if not, correct them
doc_input := $(shell egrep '^INPUT *=' $(LOCAL_DOXYFILE) | sed 's/^INPUT *=//g')
doc_input += $(LOCAL_DOXYGEN_INPUT)
doc_input := $(foreach __path,$(doc_input), \
	$(if $(call is-path-absolute,$(__path)), \
		$(__path),$(addprefix $(LOCAL_PATH)/,$(__path)) \
	))

# Use the doxyfile, but override output to out/doc and input with absolute paths
$(LOCAL_MODULE)-doc: PRIVATE_INPUT := $(doc_input)
$(LOCAL_MODULE)-doc: PRIVATE_DOXYFILE := $(LOCAL_DOXYFILE)
$(LOCAL_MODULE)-doc:
	@echo "$(PRIVATE_MODULE): Generating doxygen documentation from $(PRIVATE_DOXYFILE)"
	@rm -rf $(PRIVATE_DOC_DIR)
	@mkdir -p $(PRIVATE_DOC_DIR)
	@cd $(PRIVATE_PATH) && ( \
		cat $(PRIVATE_DOXYFILE); \
		echo "PROJECT_NAME=$(PRIVATE_MODULE)"; \
		echo "PROJECT_BRIEF=\"$(PRIVATE_DESCRIPTION)\""; \
		echo "INPUT=$(PRIVATE_INPUT)"; \
		echo "EXCLUDE_PATTERNS+=.git out sdk"; \
		echo "OUTPUT_DIRECTORY=$(PRIVATE_DOC_DIR)"; \
	) | doxygen - &> $(PRIVATE_DOC_DIR)/doxygen.log
else

# Use LOCAL_PATH and other input
doc_input := $(LOCAL_PATH) $(LOCAL_DOXYGEN_INPUT)
doc_input := $(foreach __path,$(doc_input), \
	$(if $(call is-path-absolute,$(__path)), \
		$(__path),$(addprefix $(LOCAL_PATH)/,$(__path)) \
	))

# If no doxyfile has been defined by the user, we generate one on the fly from
# a template created by doxygen which tries to document all and for all
# languages
# We disable warnings because they are plenty in this case
$(LOCAL_MODULE)-doc: PRIVATE_INPUT := $(doc_input)
$(LOCAL_MODULE)-doc:
	@echo "$(PRIVATE_MODULE): Generating doxygen documentation from generated doxyfile"
	@rm -rf $(PRIVATE_DOC_DIR)
	@mkdir -p $(PRIVATE_DOC_DIR)
	@cd $(PRIVATE_PATH) && ( \
		doxygen -g -; \
		echo "PROJECT_NAME=$(PRIVATE_MODULE)"; \
		echo "PROJECT_BRIEF=\"$(PRIVATE_DESCRIPTION)\""; \
		echo "EXTRACT_ALL=YES"; \
		echo "GENERATE_LATEX=NO"; \
		echo "WARNINGS=NO"; \
		echo "WARN_IF_DOC_ERROR=NO"; \
		echo "RECURSIVE=YES"; \
		echo "INPUT=$(PRIVATE_INPUT)"; \
		echo "EXCLUDE_PATTERNS+=.git out sdk"; \
		echo "OUTPUT_DIRECTORY=$(PRIVATE_DOC_DIR)"; \
	) | doxygen - &> $(PRIVATE_DOC_DIR)/doxygen.log

endif

###############################################################################
## Code check / cloc (count line of code) rules.
###############################################################################

# Original data before import
data_src_files := $(addprefix $(LOCAL_PATH)/,$(__modules.$(LOCAL_MODULE).SRC_FILES))
data_c_includes := $(__modules.$(LOCAL_MODULE).C_INCLUDES)
data_c_includes += $(__modules.$(LOCAL_MODULE).EXPORT_C_INCLUDES)
data_c_includes += $(LOCAL_PATH)

# Search for include files in directories with source files
data_c_includes += $(sort $(foreach __src,$(data_src_files),$(dir $(__src))))
data_c_includes := $(sort $(abspath $(data_c_includes)))

# Checkpatch is only for c files
codecheck_files := $(filter %.c,$(data_src_files))
codecheck_files += $(foreach __inc,$(data_c_includes),$(wildcard $(__inc)/*.h))

# Cpplint is only for cpp files
cppcheck_files := $(filter %.cpp,$(data_src_files))
cppcheck_files += $(filter %.cc,$(data_src_files))
cppcheck_files += $(filter %.cxx,$(data_src_files))
cppcheck_files += $(foreach __inc,$(data_c_includes),$(wildcard $(__inc)/*.hpp))
cppcheck_files += $(foreach __inc,$(data_c_includes),$(wildcard $(__inc)/*.hh))
cppcheck_files += $(foreach __inc,$(data_c_includes),$(wildcard $(__inc)/*.hxx))

# Cloc
cloc_files := $(data_src_files)
cloc_files += $(foreach __inc,$(data_c_includes),$(wildcard $(__inc)/*.h))
cloc_files += $(foreach __inc,$(data_c_includes),$(wildcard $(__inc)/*.hpp))
cloc_files += $(foreach __inc,$(data_c_includes),$(wildcard $(__inc)/*.hh))
cloc_files += $(foreach __inc,$(data_c_includes),$(wildcard $(__inc)/*.hxx))

# Sort to have unique names
codecheck_files := $(sort $(codecheck_files))
cppcheck_files := $(sort $(cppcheck_files))
cloc_files := $(sort $(cloc_files))

.PHONY: $(LOCAL_MODULE)-codecheck
$(LOCAL_MODULE)-codecheck:
	@echo "$(PRIVATE_MODULE): Checking files...";
	@$(BUILD_SYSTEM)/scripts/checkpatch.pl \
		--no-tree --no-summary --terse --show-types -f \
		--ignore SPLIT_STRING \
		$(PRIVATE_CODECHECK_ARGS) $(PRIVATE_CODECHECK_FILES) \
	|| true;

.PHONY: $(LOCAL_MODULE)-cppcheck
$(LOCAL_MODULE)-cppcheck:
	@echo "$(PRIVATE_MODULE): Checking files...";
	@for f in $(PRIVATE_CPPCHECK_FILES); do \
		echo "$(PRIVATE_MODULE): Checking file $${f#$(TOP_DIR)/}"; \
		$(BUILD_SYSTEM)/scripts/cpplint.py \
			--extension hpp,cpp,cxx,hxx,cc,hh \
			--counting detailed --verbose 0 \
			$(PRIVATE_CPPCHECK_ARGS) $$f \
		|| true; \
	done

.PHONY: $(LOCAL_MODULE)-cloc
$(LOCAL_MODULE)-cloc:
	@mkdir -p $(PRIVATE_BUILD_DIR)
	@:> $(PRIVATE_BUILD_DIR)/cloc-list.txt
	@for f in $(PRIVATE_CLOC_FILES); do \
		echo $${f} >> $(PRIVATE_BUILD_DIR)/cloc-list.txt; \
	done
	$(Q) cloc --list-file=$(PRIVATE_BUILD_DIR)/cloc-list.txt \
		--by-file --xml \
		--out $(PRIVATE_BUILD_DIR)/cloc.xml

# Define target variables because we don't inherit from 'standard' targets
$(LOCAL_MODULE)-codecheck: PRIVATE_MODULE := $(LOCAL_MODULE)
$(LOCAL_MODULE)-codecheck: PRIVATE_BUILD_DIR := $(build_dir)
$(LOCAL_MODULE)-codecheck: PRIVATE_CODECHECK_FILES := $(codecheck_files)
$(LOCAL_MODULE)-codecheck: PRIVATE_CODECHECK_ARGS := $(LOCAL_CODECHECK_ARGS)

$(LOCAL_MODULE)-cppcheck: PRIVATE_MODULE := $(LOCAL_MODULE)
$(LOCAL_MODULE)-cppcheck: PRIVATE_BUILD_DIR := $(build_dir)
$(LOCAL_MODULE)-cppcheck: PRIVATE_CPPCHECK_FILES := $(cppcheck_files)
$(LOCAL_MODULE)-cppcheck: PRIVATE_CPPCHECK_ARGS := $(LOCAL_CPPCHECK_ARGS)

$(LOCAL_MODULE)-cloc: PRIVATE_MODULE := $(LOCAL_MODULE)
$(LOCAL_MODULE)-cloc: PRIVATE_BUILD_DIR := $(build_dir)
$(LOCAL_MODULE)-cloc: PRIVATE_CLOC_FILES := $(cloc_files)

###############################################################################
## Files to copy.
###############################################################################

ifneq ("$(LOCAL_COPY_FILES)","")

# List of all source/destination files
all_copy_files_src :=
all_copy_files_dst :=

# Generate a rule to copy all files
# Handle relative/absolute paths
# Handle directory only for destination
$(foreach __pair,$(LOCAL_COPY_FILES), \
	$(eval __pair2 := $(subst :,$(space),$(__pair))) \
	$(eval __w1 := $(word 1,$(__pair2))) \
	$(eval __w2 := $(word 2,$(__pair2))) \
	$(eval __src := $(call copy-get-src-path,$(__w1))) \
	$(eval __dst := $(call copy-get-dst-path$(mode_suffix),$(__w2))) \
	$(if $(call is-path-dir,$(__dst)), \
		$(eval __dst := $(__dst)$(notdir $(__src))) \
	) \
	$(eval all_copy_files_src += $(__src)) \
	$(eval all_copy_files_dst += $(__dst)) \
	$(eval $(call copy-one-file,$(__src),$(__dst))) \
)

# Add an order-only dependency between sources and prerequisites
all_copy_files_prerequisites := \
	$(filter-out $(all_copy_files_src) $(all_copy_files_dst),$(all_prerequisites))
$(foreach __src,$(all_copy_files_src), \
	$(if $(filter $(__src),$(all_prerequisites)),$(empty), \
		$(eval $(__src): | $(all_copy_files_prerequisites)) \
	) \
)

# Add files to be copied as an order-only dependency (does not force rebuild)
$(LOCAL_BUILD_MODULE): | $(all_copy_files_dst)

# Add rule to delete copied files during clean
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(all_copy_files_dst)

# Remove destination of files to copy from prerequisites
all_prerequisites := $(filter-out $(all_copy_files_dst),$(all_prerequisites))

endif

###############################################################################
## Links to create.
###############################################################################

ifneq ("$(LOCAL_CREATE_LINKS)","")

# List of all links
all_create_links :=

# Generate a rule to create links
$(foreach __pair,$(LOCAL_CREATE_LINKS), \
	$(eval __pair2 := $(subst :,$(space),$(__pair))) \
	$(eval __w1 := $(word 1,$(__pair2))) \
	$(eval __w2 := $(word 2,$(__pair2))) \
	$(eval __name := $($(mode_prefix)OUT_STAGING)/$(__w1)) \
	$(eval __target := $(__w2)) \
	$(eval all_create_links += $(__name)) \
	$(eval $(call create-one-link,$(__name),$(__target))) \
)

# Add links to be created as an order-only dependency (does not force rebuild)
$(LOCAL_BUILD_MODULE): | $(all_create_links)

# Add rule to delete created links during clean
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(all_create_links)

endif

###############################################################################
## Prerequisites.
###############################################################################

# Make sure all prerequisites files are generated first
# But do NOT force recompilation (order only)
$(LOCAL_BUILD_MODULE): | $(all_prerequisites)

# Prerequisites that are not ours
all_external_prerequisites := $(filter-out \
	$(LOCAL_CUSTOM_TARGETS) \
	$(LOCAL_PREREQUISITES) \
	$(LOCAL_EXPORT_PREREQUISITES), $(all_prerequisites))

# Same thing for custom targets of the module (but excludes the ones of the module)
$(LOCAL_CUSTOM_TARGETS): | $(all_external_prerequisites)
$(LOCAL_PREREQUISITES): | $(all_external_prerequisites)
$(LOCAL_EXPORT_PREREQUISITES): | $(all_external_prerequisites)

###############################################################################
## Static library.
###############################################################################

ifeq ("$(LOCAL_MODULE_CLASS)","STATIC_LIBRARY")
ifeq ("$(LOCAL_SDK)","")

include $(BUILD_SYSTEM)/binary-rules.mk

$(LOCAL_BUILD_MODULE): $(all_objects)
	$(transform-o-to-static-lib)
	$(call copy-license-files,$(PRIVATE_PATH),$(PRIVATE_BUILD_DIR))
	@touch $@.done

ifneq ("$(LOCAL_NO_COPY_TO_STAGING)","1")
copy_to_staging := 1
endif

endif
endif

###############################################################################
## Shared library.
###############################################################################

ifeq ("$(LOCAL_MODULE_CLASS)","SHARED_LIBRARY")
ifeq ("$(LOCAL_SDK)","")

include $(BUILD_SYSTEM)/binary-rules.mk

$(LOCAL_BUILD_MODULE): $(all_objects) $(all_link_libs_filenames)
	$(transform-o-to-shared-lib)
ifneq ("$(TARGET_ADD_DEPENDS_SECTION)","0")
	$(add-depends-section)
endif
ifneq ("$(TARGET_ADD_BUILDID_SECTION)","0")
	$(add-buildid-section)
endif
	$(call copy-license-files,$(PRIVATE_PATH),$(PRIVATE_BUILD_DIR))
	@touch $@.done

ifneq ("$(LOCAL_NO_COPY_TO_STAGING)","1")
copy_to_staging := 1
copy_to_final := 1
endif

endif
endif

###############################################################################
## Generic library, both shared and static version is built.
###############################################################################

ifeq ("$(LOCAL_MODULE_CLASS)","LIBRARY")
ifeq ("$(LOCAL_SDK)","")

include $(BUILD_SYSTEM)/binary-rules.mk

# Static version
$(LOCAL_BUILD_MODULE_STATIC): $(all_objects) $(all_link_libs_filenames)
	$(transform-o-to-static-lib)
	@touch $@.done

# Shared version
$(LOCAL_BUILD_MODULE): $(all_objects) $(all_link_libs_filenames)
	$(transform-o-to-shared-lib)
ifneq ("$(TARGET_ADD_DEPENDS_SECTION)","0")
	$(add-depends-section)
endif
ifneq ("$(TARGET_ADD_BUILDID_SECTION)","0")
	$(add-buildid-section)
endif
	$(call copy-license-files,$(PRIVATE_PATH),$(PRIVATE_BUILD_DIR))
	@touch $@.done

ifneq ("$(LOCAL_NO_COPY_TO_STAGING)","1")
copy_to_staging := 1
copy_to_final := 1
endif

endif
endif

###############################################################################
## Executable.
###############################################################################

ifeq ("$(LOCAL_MODULE_CLASS)","EXECUTABLE")

include $(BUILD_SYSTEM)/binary-rules.mk

ifneq ("$(LOCAL_LDSCRIPT)","")
$(LOCAL_BUILD_MODULE): $(LOCAL_PATH)/$(LOCAL_LDSCRIPT)
$(LOCAL_BUILD_MODULE): PRIVATE_LDFLAGS += -T $(LOCAL_PATH)/$(LOCAL_LDSCRIPT)
endif

$(LOCAL_BUILD_MODULE): $(all_objects) $(all_link_libs_filenames)
	$(transform-o-to-executable)
ifneq ("$(TARGET_ADD_DEPENDS_SECTION)","0")
	$(add-depends-section)
endif
ifneq ("$(TARGET_ADD_BUILDID_SECTION)","0")
	$(add-buildid-section)
endif
	$(call copy-license-files,$(PRIVATE_PATH),$(PRIVATE_BUILD_DIR))
	@touch $@.done

ifneq ("$(LOCAL_NO_COPY_TO_STAGING)","1")
copy_to_staging := 1
copy_to_final := 1
endif

endif

###############################################################################
## Autotools.
###############################################################################

ifeq ("$(LOCAL_MODULE_CLASS)","AUTOTOOLS")

include $(BUILD_SYSTEM)/autotools-rules.mk

endif

###############################################################################
## CMake.
###############################################################################

ifeq ("$(LOCAL_MODULE_CLASS)","CMAKE")

include $(BUILD_SYSTEM)/cmake-rules.mk

endif

###############################################################################
## QMake.
###############################################################################

ifeq ("$(LOCAL_MODULE_CLASS)","QMAKE")

include $(BUILD_SYSTEM)/qmake-rules.mk

endif

###############################################################################
## Python extension.
###############################################################################

ifeq ("$(LOCAL_MODULE_CLASS)","PYTHON_EXTENSION")

include $(BUILD_SYSTEM)/python-ext-rules.mk

endif

###############################################################################
## Prebuilt.
###############################################################################

ifeq ("$(LOCAL_MODULE_CLASS)","PREBUILT")

# Simply 'touch' the 'done' file
$(LOCAL_BUILD_MODULE):
	@mkdir -p $(dir $@)
	@touch $@

endif

###############################################################################
## Typelib gobject-introspection library.
###############################################################################

ifeq ("$(LOCAL_MODULE_CLASS)","GI_TYPELIB")

include $(BUILD_SYSTEM)/gobject-introspection-rules.mk

# Gir file
$(LOCAL_BUILD_MODULE:.typelib=.gir): $(all_link_libs_filenames) $(all_sources)
	$(transform-c-to-gir)

# Typelib library
$(LOCAL_BUILD_MODULE): $(LOCAL_BUILD_MODULE:.typelib=.gir)
	$(transform-gir-to-typelib)

ifneq ("$(LOCAL_NO_COPY_TO_STAGING)","1")
copy_to_staging := 1
copy_to_final := 1
endif

endif


###############################################################################
## Custom.
###############################################################################

ifeq ("$(LOCAL_MODULE_CLASS)","CUSTOM")

# This makes sure that the done file will be created. However this may trigger
# a rebuilt of some modules in a new execution of the build because this rule
# is executed at any time, and there is no build order associated.
$(LOCAL_MODULE):
	$(create-done-file)

endif

###############################################################################
## Meta package.
###############################################################################

ifeq ("$(LOCAL_MODULE_CLASS)","META_PACKAGE")

# This makes sure that the done file will be created. However this may trigger
# a rebuilt of some modules in a new execution of the build because this rule
# is executed at any time, and there is no build order associated.
$(LOCAL_MODULE):
	$(create-done-file)

# Add a meta package dependency
# $1 : module name
# $2 : dependency name
define __meta-package-dep
$1: $2
$1-clean: $2-clean
$1-dirclean: $2-dirclean
endef

# Add deps for build, clean, dirclean
$(foreach __mod,$(call module-get-config-depends,$(LOCAL_MODULE)), \
	$(eval $(call __meta-package-dep,$(LOCAL_MODULE),$(__mod))) \
)

endif

###############################################################################
## Copy to staging/final dir
###############################################################################

ifeq ("$(copy_to_staging)","1")

$(LOCAL_MODULE): $(LOCAL_STAGING_MODULE)
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(LOCAL_STAGING_MODULE)
$(eval $(call copy-one-file,$(LOCAL_BUILD_MODULE),$(LOCAL_STAGING_MODULE)))

ifeq ("$(LOCAL_MODULE_CLASS)","LIBRARY")
$(LOCAL_MODULE): $(LOCAL_STAGING_MODULE_STATIC)
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(LOCAL_STAGING_MODULE_STATIC)
$(eval $(call copy-one-file,$(LOCAL_BUILD_MODULE_STATIC),$(LOCAL_STAGING_MODULE_STATIC)))
endif

# If final directory exists, also copy file in it
# TODO: maybe add a setting to disable this feature ?
# TODO: add to clean list ?
ifeq ("$(copy_to_final)","1")

ifeq ("$(mode_host)","")
ifneq ("$(wildcard $(TARGET_OUT_FINAL))","")

LOCAL_FINAL_MODULE := $(LOCAL_STAGING_MODULE:$(TARGET_OUT_STAGING)/%=$(TARGET_OUT_FINAL)/%)
$(LOCAL_MODULE): $(LOCAL_FINAL_MODULE)

# Strip if needed, otherwise simply copy
ifeq ("$(TARGET_NOSTRIP_FINAL)","1")
$(eval $(call copy-one-file,$(LOCAL_STAGING_MODULE),$(LOCAL_FINAL_MODULE)))
else ifneq ("$(filter $(TARGET_STRIP_FILTER),$(LOCAL_MODULE_FILENAME))","")
$(eval $(call copy-one-file,$(LOCAL_STAGING_MODULE),$(LOCAL_FINAL_MODULE)))
else
$(LOCAL_FINAL_MODULE): $(LOCAL_STAGING_MODULE)
	@echo "Strip: $(call path-from-top,$<) => $(call path-from-top,$@)"
	@mkdir -p $(dir $@)
	$(Q)$(TARGET_STRIP) -o $@ $<
endif

endif # ifneq ("$(wildcard $(TARGET_OUT_FINAL))","")
endif # ifeq ("$(mode_host)","")

endif # ifeq ("$(copy_to_final)","1")

endif # ifeq ("$(copy_to_staging)","1")

###############################################################################
## Pre-install customization
###############################################################################

ifneq ("$(value LOCAL_CMD_PRE_INSTALL)","")

$(preinstall_file):
	+$(call macro-exec-cmd,CMD_PRE_INSTALL,empty)
	@mkdir -p $(dir $@)
	@touch $@

$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(preinstall_file)

# Do the pre-install hook after module is built
$(LOCAL_MODULE): $(preinstall_file)
$(preinstall_file): $(LOCAL_BUILD_MODULE)

# If a copy in staging is done do it before.
ifeq ("$(copy_to_staging)","1")
$(LOCAL_STAGING_MODULE): | $(preinstall_file)
endif

endif
