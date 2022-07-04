###############################################################################
## @file classes/rules.mk
## @author Y.M. Morgan
## @date 2016/03/09
##
## Rules for module classes.
###############################################################################

# Make sure module is registered otherwise restoring variables will fail
ifeq ("$(call is-module-registered,$(LOCAL_MODULE))","")
$(warning Unknown module $(LOCAL_MODULE))
else

# Bring back all LOCAL_XXX variables defined by LOCAL_MODULE
$(call module-restore-locals,$(LOCAL_MODULE))

ifneq ("$(V)","0")
  $(info Generating rules for $(LOCAL_MODULE))
endif

# Host/Target module customization
# Prefix is used for variable like TARGET_xxx or LOCAL_xxx
# Suffix is for macros.
ifneq ("$(LOCAL_HOST_MODULE)","")
  _mode_host := $(true)
  _mode_prefix := HOST
  _mode_suffix := -host
else
  _mode_host :=
  _mode_prefix := TARGET
  _mode_suffix :=
endif

# Build directory
_module_build_dir := $(call module-get-build-dir,$(LOCAL_MODULE))

_module_unpacked_stamp_file     := $(call module-get-stamp-file,$(LOCAL_MODULE),unpacked)
_module_patched_stamp_file      := $(call module-get-stamp-file,$(LOCAL_MODULE),patched)
_module_bootstrapped_stamp_file := $(call module-get-stamp-file,$(LOCAL_MODULE),bootstrapped)
_module_configured_stamp_file   := $(call module-get-stamp-file,$(LOCAL_MODULE),configured)
_module_built_stamp_file        := $(call module-get-stamp-file,$(LOCAL_MODULE),built)
_module_installed_stamp_file    := $(call module-get-stamp-file,$(LOCAL_MODULE),installed)
_module_done_stamp_file         := $(call module-get-stamp-file,$(LOCAL_MODULE),done)

_module_all_stamp_files := \
	$(_module_unpacked_stamp_file) \
	$(_module_patched_stamp_file) \
	$(_module_bootstrapped_stamp_file) \
	$(_module_configured_stamp_file) \
	$(_module_built_stamp_file) \
	$(_module_installed_stamp_file) \
	$(_module_done_stamp_file)

# Module Architecture
ifneq ("$(LOCAL_HOST_MODULE)","")
  _module_arch := $(HOST_ARCH)
else ifeq ("$(TARGET_ARCH)","arm")
  # Can be arm or thumb
  LOCAL_ARM_MODE := $(strip $(LOCAL_ARM_MODE))
  ifeq ("$(LOCAL_ARM_MODE)","")
    ifneq ("$(call is-module-external,$(LOCAL_MODULE))","")
      LOCAL_ARM_MODE := $(TARGET_DEFAULT_ARM_MODE_EXTERNAL)
    else
      LOCAL_ARM_MODE := $(TARGET_DEFAULT_ARM_MODE)
    endif
  endif
  _module_arch := $(LOCAL_ARM_MODE)
else
  _module_arch := $(TARGET_ARCH)
endif

_module_cc_flavour := $($(_mode_prefix)_CC_FLAVOUR)
_module_cc         := $($(_mode_prefix)_CC)
_module_cxx        := $($(_mode_prefix)_CXX)
_module_fc         := $($(_mode_prefix)_FC)
_module_as         := $($(_mode_prefix)_AS)
_module_ar         := $($(_mode_prefix)_AR)
_module_ld         := $($(_mode_prefix)_LD)
_module_nm         := $($(_mode_prefix)_NM)
_module_strip      := $($(_mode_prefix)_STRIP)
_module_cpp        := $($(_mode_prefix)_CPP)
_module_ranlib     := $($(_mode_prefix)_RANLIB)
_module_objcopy    := $($(_mode_prefix)_OBJCOPY)
_module_objdump    := $($(_mode_prefix)_OBJDUMP)
_module_windres    := $($(_mode_prefix)_WINDRES)

# Override some values if clang should be used locally
ifeq ("$(LOCAL_USE_CLANG)","1")
  ifneq ("$(_module_cc_flavour)","clang")
    $(_module_cc_flavour) := clang
    ifneq ("$(LOCAL_CLANG_PATH)","")
      _module_cc := $(LOCAL_CLANG_PATH)/clang
      _module_cxx := $(LOCAL_CLANG_PATH)/clang++
    else
      _module_cc := clang
      _module_cxx := clang++
    endif
  endif
endif

# Full path to build/staging module
LOCAL_BUILD_MODULE := $(call module-get-build-filename,$(LOCAL_MODULE))
LOCAL_STAGING_MODULE := $(call module-get-staging-filename,$(LOCAL_MODULE))

# Assemble the list of targets to create PRIVATE_ variables for.
LOCAL_TARGETS := \
	$(_module_all_stamp_files) \
	$(LOCAL_CUSTOM_TARGETS) \
	$(LOCAL_BUILD_MODULE) \
	$(LOCAL_MODULE) \
	$(LOCAL_MODULE)-clean \
	$(LOCAL_MODULE)-dirclean \
	$(LOCAL_MODULE)-path \
	$(LOCAL_MODULE)-doc \
	$(LOCAL_MODULE)-cloc \
	$(call codecheck-get-targets,$(LOCAL_MODULE)) \
	$(call codeformat-get-targets,$(LOCAL_MODULE)) \
	$(call genproject-get-targets,$(LOCAL_MODULE))

# Configuration file.
_module_orig_config_file := $(call __get-orig-module-config,$(LOCAL_MODULE))
_module_build_config_file := $(call __get-build-module-config,$(LOCAL_MODULE))
_module_autoconf_file := $(call module-get-autoconf,$(LOCAL_MODULE))

# Include file with revision use for last build. It will define a variable
# if available.
_module_revision_file :=
_module_revision_h_file :=
ifneq ("$(USE_GIT_REV)","0")
  _module_revision_file := $(_module_build_dir)/$(LOCAL_MODULE).revision
  _module_revision_h_file := $(_module_build_dir)/$(LOCAL_MODULE)-revision.h
  -include $(_module_revision_file)
endif

# Get all modules we depend on (fully recursive)
all_depends := $(call module-get-all-depends,$(LOCAL_MODULE))

# Imported custom variables
imported_CUSTOM_VARIABLES := $(call module-get-listed-export,$(all_depends),CUSTOM_VARIABLES)

###############################################################################
## Expand exported custom variables if requested in all LOCAL_xxx variables.
###############################################################################
ifeq ("$(LOCAL_EXPAND_CUSTOM_VARIABLES)","1")
expand-custom = \
	$(foreach __var,$(sort $(vars-LOCAL)), \
		$(if $(findstring $(percent){CUSTOM_$1},$(LOCAL_$(__var))), \
			$(if $(call strneq,$(V),0), \
				$(info $(LOCAL_MODULE): Expanding CUSTOM_$1 in LOCAL_$(__var)) \
			) \
			$(eval LOCAL_$(__var) := $(subst $(percent){CUSTOM_$1},$2,$(LOCAL_$(__var)))) \
		) \
	)
$(call var-list-foreach,$(imported_CUSTOM_VARIABLES),expand-custom)
endif

###############################################################################
## ARM specific checks.
###############################################################################
ifeq ("$(_mode_host)","")
ifeq ("$(TARGET_ARCH)","arm")

# Make sure LOCAL_ARM_MODE is valid
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
check-flags-arch-cpu := -march=% -mcpu=% -mtune=%
check-flags-arch-cpu-message := please let alchemy or product determine arch/cpu flags

# Unfortunately, there is one use case where a module overwrites the -mfpu=
# due to a bug in 2012 toolchain
# Also allow android armv7a to specify neon (can break at runtime if wrongly used)
ifeq ("$(call str-starts-with,$(TARGET_CC_PATH),/opt/arm-2012.03)","")
ifneq ("$(TARGET_OS)-$(TARGET_OS_FLAVOUR)-$(TARGET_CPU)","linux-android-armv7a")
  check-flags-arch-cpu += -mfloat-abi=% -mfpu=%
endif
endif

$(call check-flags,LOCAL_CFLAGS,$(check-flags-arch-cpu),$(check-flags-arch-cpu-message))
$(call check-flags,LOCAL_CXXFLAGS,$(check-flags-arch-cpu),$(check-flags-arch-cpu-message))
$(call check-flags,LOCAL_EXPORT_CFLAGS,$(check-flags-arch-cpu),$(check-flags-arch-cpu-message))
$(call check-flags,LOCAL_EXPORT_CXXFLAGS,$(check-flags-arch-cpu),$(check-flags-arch-cpu-message))

###############################################################################
## Dependencies.
###############################################################################

# Get libraries used by us and static libraries
all_meta_packages := \
	$(call module-get-static-depends,$(LOCAL_MODULE),META_PACKAGES)
all_prebuilt_libs := \
	$(call module-get-static-depends,$(LOCAL_MODULE),PREBUILT_LIBRARIES)
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
	$(all_meta_packages) \
	$(all_prebuilt_libs) \
	$(all_external_libs) \
	$(all_static_libs) \
	$(all_whole_static_libs) \
	$(all_shared_libs)

# Stamp file for installation of all dependencies
all_depends_installed_stamp := \
	$(foreach __lib,$(all_depends), \
		$(call module-get-stamp-file,$(__lib),installed) \
	)

# For generic library, force retrieving static version if needed

all_static_libs_filename := \
	$(foreach __lib,$(all_static_libs), \
		$(if $(call streq,$(__modules.$(__lib).MODULE_CLASS),LIBRARY), \
			$(call module-get-static-lib-staging-filename,$(__lib)) \
			, \
			$(call module-get-staging-filename,$(__lib)) \
		) \
	)

all_whole_static_libs_filename := \
	$(foreach __lib,$(all_whole_static_libs), \
		$(if $(call streq,$(__modules.$(__lib).MODULE_CLASS),LIBRARY), \
			$(call module-get-static-lib-staging-filename,$(__lib)) \
			, \
			$(call module-get-staging-filename,$(__lib)) \
		) \
	)

all_shared_libs_filename := \
	$(foreach __lib,$(all_shared_libs), \
		$(call module-get-staging-filename,$(__lib)) \
	)

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
## Construct prerequisites.
###############################################################################

# List of all prerequisites (ours + dependencies)
all_prerequisites :=

# We need all external libraries installed as prerequisites.
all_prerequisites += \
	$(foreach __lib,$(all_depends), \
		$(if $(call is-module-external,$(__lib)), \
			$(call module-get-stamp-file,$(__lib),installed) \
		) \
	)

all_prerequisites += \
	$(LOCAL_PREREQUISITES) \
	$(LOCAL_EXPORT_PREREQUISITES)

# Do not add global prerequisites if our module is one of them.
# FIXME: do NOT add TARGET_GLOBAL_PREREQUISITES for host modules
ifeq ("$(filter $(LOCAL_MODULE),$(TARGET_GLOBAL_PREREQUISITES))","")
  all_prerequisites += $(filter-out $(LOCAL_MODULE) $(LOCAL_BUILD_MODULE),$(TARGET_GLOBAL_PREREQUISITES))
endif

# Make sure autoconf.h file is generated
all_prerequisites += $(_module_autoconf_file)
all_prerequisites += $(_module_revision_h_file)

# Make sure PRIVATE_XXX variables of prerequisites are correct
# Without this, the first module that needs the prerequisite will force its
# PRIVATE_XXX variables leading to 'interresting' results
LOCAL_TARGETS += \
	$(LOCAL_PREREQUISITES) \
	$(LOCAL_EXPORT_PREREQUISITES) \
	$(_module_autoconf_file) \
	$(_module_revision_h_file)

# Modules required (both host and target)
all_prerequisites += \
	$(foreach __mod,$(LOCAL_DEPENDS_HOST_MODULES) $(LOCAL_DEPENDS_MODULES), \
		$(call module-get-stamp-file,$(__mod),done))

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
ifeq ("$(and $(call is-module-external,$(LOCAL_MODULE)),$(call strneq,$(LOCAL_MODULE_CLASS),QMAKE),$(call strneq,$(LOCAL_MODULE_CLASS),LINUX_MODULE))","")
  # Internal module or QMAKE module or LINUX_MODULE
  imported_CFLAGS        := $(call module-get-listed-export,$(all_depends),CFLAGS)
  imported_CXXFLAGS      := $(call module-get-listed-export,$(all_depends),CXXFLAGS)
  imported_C_INCLUDES    := $(call module-get-listed-export,$(all_depends),C_INCLUDES)
  imported_LDFLAGS       := $(call module-get-listed-export,$(all_libs),LDFLAGS)
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
  imported_LDFLAGS       := $(call module-get-listed-export,$(call filter-get-internal-modules,$(all_libs)),LDFLAGS)
  imported_LDLIBS        := $(call module-get-listed-export,$(call filter-get-internal-modules,$(all_libs)),LDLIBS)
endif

# Add includes of modules listed in LOCAL_DEPENDS_HEADERS
imported_C_INCLUDES += $(call module-get-listed-export,$(LOCAL_DEPENDS_HEADERS),C_INCLUDES)

# Move include flags from CFLAGS/CXXFLAGS to C_INCLUDES
imported_C_INCLUDES += $(patsubst -I%,%,$(filter -I%,$(imported_CFLAGS) $(imported_CXXFLAGS)))
imported_CFLAGS := $(filter-out -I%,$(imported_CFLAGS))
imported_CXXFLAGS := $(filter-out -I%,$(imported_CXXFLAGS))

# Import prerequisites (the one for this module are already in all_prerequisites)
imported_PREREQUISITES := $(call module-get-listed-export,$(all_depends),PREREQUISITES)
all_prerequisites += $(imported_PREREQUISITES)

# The imported/exported compiler flags are prepended to their LOCAL_XXXX value
# (this allows the module to override them).
LOCAL_CFLAGS := $(strip $(imported_CFLAGS) $(LOCAL_CFLAGS))
LOCAL_CXXFLAGS := $(strip $(imported_CXXFLAGS) $(LOCAL_CXXFLAGS))

# The imported/exported include directories are appended to their LOCAL_XXX value
# (this allows the module to override them)
LOCAL_C_INCLUDES := $(strip $(LOCAL_C_INCLUDES) $(imported_C_INCLUDES))

# Similarly, you want the imported/exported flags to appear _after_ the
# LOCAL_LDFLAGS and LOCAL_LDLIBS due to the way Unix linkers work (depending
# libraries must appear before dependees on final link command).
LOCAL_LDFLAGS := $(strip $(LOCAL_LDFLAGS) $(imported_LDFLAGS))
LOCAL_LDLIBS := $(strip $(LOCAL_LDLIBS) $(imported_LDLIBS))

# Simplify variable by keeping only first occurence of each item
LOCAL_C_INCLUDES := $(strip $(call uniq,$(LOCAL_C_INCLUDES)))

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

# Add autoconf of modules listed in LOCAL_DEPENDS_HEADERS
all_autoconf += $(call module-get-listed-autoconf, \
	$(LOCAL_DEPENDS_HEADERS))

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

# Code coverage & analysis flags (for internal, non host modules only)
ifeq ("$(_mode_host)","")
ifeq ("$(and $(call is-module-external,$(LOCAL_MODULE)),$(call strneq,$(LOCAL_MODULE_CLASS),QMAKE))","")
ifneq ($(call is-sanitizer-enabled,$(USE_ADDRESS_SANITIZER),$(LOCAL_MODULE)),)
  LOCAL_CFLAGS += -fsanitize=address -fno-omit-frame-pointer -fno-optimize-sibling-calls -O1 -D__ADDRESSSANITIZER__
  LOCAL_LDFLAGS += -fsanitize=address
endif
ifneq ($(call is-sanitizer-enabled,$(USE_MEMORY_SANITIZER),$(LOCAL_MODULE)),)
  LOCAL_CFLAGS += -fsanitize=memory -fno-omit-frame-pointer -fno-optimize-sibling-calls -O1 -D__MEMORYSANITIZER__
  LOCAL_LDFLAGS += -fsanitize=memory
endif
ifneq ($(call is-sanitizer-enabled,$(USE_THREAD_SANITIZER),$(LOCAL_MODULE)),)
  LOCAL_CFLAGS += -fsanitize=thread -O1 -D__THREADSANITIZER__
  LOCAL_LDFLAGS += -fsanitize=thread
endif
ifneq ($(call is-sanitizer-enabled,$(USE_UNDEFINED_SANITIZER),$(LOCAL_MODULE)),)
  LOCAL_CFLAGS += -fsanitize=undefined -fno-omit-frame-pointer -fno-optimize-sibling-calls -O1 -D__UNDEFINEDSANITIZER__
  LOCAL_LDFLAGS += -fsanitize=undefined
endif
ifneq ($(call is-sanitizer-enabled,$(USE_COVERAGE),$(LOCAL_MODULE)),)
  LOCAL_CFLAGS  += --coverage -D__COVERAGE__
  LOCAL_LDFLAGS += --coverage
  ifeq ($(filter optimized,$(USE_COVERAGE)),)
    LOCAL_CFLAGS  += -O0 -U_FORTIFY_SOURCE
  endif
endif
endif
endif

###############################################################################
## Prepend global flags depending on compiler arch
## Not done for linux module because global flags are for userspace components only.
###############################################################################

ifneq ("$(LOCAL_MODULE_CLASS)","LINUX_MODULE")

LOCAL_CFLAGS := \
	$($(_mode_prefix)_GLOBAL_CFLAGS_$(_module_arch)) \
	$(LOCAL_CFLAGS)

LOCAL_LDFLAGS := \
	$($(_mode_prefix)_GLOBAL_LDFLAGS_$(_module_arch)) \
	$(LOCAL_LDFLAGS)

endif

###############################################################################
## Determine flags that external modules will need to add manually.
## External modules (AUTOTOOLS, CMAKE) only have ASFLAGS CFLAGS CXXFLAGS and LDFLAGS.
## Moreover CXXFLAGS does not inherit from CFLAGS so it must contains it.
###############################################################################

_external_add_ASFLAGS := \
	$(LOCAL_ASFLAGS)

_external_add_CFLAGS := \
	$(call normalize-c-includes,$(LOCAL_C_INCLUDES)) \
	$(LOCAL_CFLAGS)

_external_add_CXXFLAGS := \
	$(filter-out -std=%,$(_external_add_CFLAGS)) \
	$(LOCAL_CXXFLAGS)

_external_add_LDFLAGS := \
	$(LOCAL_LDFLAGS)

# Whole static libraries
# As one unique -Wl option otherwise libtool makes a terrible mess with it
# (it splits -Wl otions from -l options making encapsulation useless)
# With -l: to force using the given path
ifneq ("$(strip $(all_whole_static_libs_filename))","")
_external_add_LDFLAGS += -Wl,--whole-archive
$(foreach __lib,$(all_whole_static_libs_filename), \
	$(if $(filter lib%$($(_mode_prefix)_STATIC_LIB_SUFFIX),$(notdir $(__lib))), \
		$(eval _external_add_LDFLAGS := \
			$(_external_add_LDFLAGS),-l$(patsubst lib%$($(_mode_prefix)_STATIC_LIB_SUFFIX),%,$(notdir $(__lib)))) \
		, \
		$(eval _external_add_LDFLAGS := \
			$(_external_add_LDFLAGS),-l:$(notdir $(__lib))) \
	) \
)
_external_add_LDFLAGS := $(_external_add_LDFLAGS),--no-whole-archive
endif

# Static libraries
# With -l: to force using the given path
# No comma separated list (like above or below !)
ifneq ("$(strip $(all_static_libs_filename))","")
$(foreach __lib,$(all_static_libs_filename), \
	$(if $(filter lib%$($(_mode_prefix)_STATIC_LIB_SUFFIX), $(notdir $(__lib))), \
		$(eval _external_add_LDFLAGS := \
			$(_external_add_LDFLAGS) -l$(patsubst lib%$($(_mode_prefix)_STATIC_LIB_SUFFIX),%,$(notdir $(__lib)))) \
		, \
		$(eval _external_add_LDFLAGS := \
			$(_external_add_LDFLAGS) -l:$(notdir $(__lib))) \
	) \
)
endif

# Shared libraries
# As one unique -Wl option otherwise libtool make a terrible mess with it
# (it splits -Wl otions from -l options making encapsulation useless)
# With -l: to force using the given path
ifneq ("$(strip $(all_shared_libs_filename))","")
_external_add_LDFLAGS += -Wl
$(foreach __lib,$(all_shared_libs_filename), \
	$(if $(filter lib%$($(_mode_prefix)_SHARED_LIB_SUFFIX), $(notdir $(__lib))), \
		$(eval _external_add_LDFLAGS := \
			$(_external_add_LDFLAGS),-l$(patsubst lib%$($(_mode_prefix)_SHARED_LIB_SUFFIX),%,$(notdir $(__lib)))) \
		, \
		$(eval _external_add_LDFLAGS := \
			$(_external_add_LDFLAGS),-l:$(notdir $(__lib))) \
	) \
)
endif

# Add local defined flags and libs
_external_add_LDFLAGS += $(LOCAL_LDFLAGS) $(LOCAL_LDLIBS)

###############################################################################
## Copy to build dir.
###############################################################################

_module_copy_to_build_dir_src_files :=
_module_copy_to_build_dir_dst_dir := $(_module_build_dir)
_module_copy_to_build_dir_dst_files :=

ifeq ("$(LOCAL_COPY_TO_BUILD_DIR)","1")

# All files under LOCAL_PATH
_module_copy_to_build_dir_src_files := $(shell find $(LOCAL_PATH) \
	-name '.git' -prune -o \
	-name '$(USER_MAKEFILE_NAME)' -prune -o \
	$(foreach __f,$(addprefix $(LOCAL_PATH)/,$(LOCAL_COPY_TO_BUILD_DIR_SKIP_FILES)),-path $(__f) -prune -o) \
	-not -type d -print)

# Where they wil be copied
_module_copy_to_build_dir_dst_files := $(patsubst $(LOCAL_PATH)/%,$(_module_copy_to_build_dir_dst_dir)/%, \
	$(_module_copy_to_build_dir_src_files))

# Add rule to copy them
$(foreach __f,$(_module_copy_to_build_dir_src_files), \
	$(eval $(call copy-one-file,$(__f),$(patsubst $(LOCAL_PATH)/%,$(_module_copy_to_build_dir_dst_dir)/%,$(__f)))) \
)

all_prerequisites += $(_module_copy_to_build_dir_dst_files)

endif

###############################################################################
## Archive extraction + patches.
## Do this step if there is no archive but there is a post unpack command.
## This is to handle cases where a pre-configure step is needed but no
## real archive to unpack. And because there is no pre-cmd variables at the
## moment.
###############################################################################
_module_archive_file :=
_module_archive_patches :=

ifneq ("$(or $(LOCAL_ARCHIVE),$(value LOCAL_ARCHIVE_CMD_POST_UNPACK))","")

# Full path to archive file (can be empty if we only want post unpack command)
ifneq ("$(strip $(LOCAL_ARCHIVE))","")
  _module_archive_file := $(LOCAL_PATH)/$(LOCAL_ARCHIVE)
endif

# Patches to apply
_module_archive_patches := $(strip $(LOCAL_ARCHIVE_PATCHES))

endif

###############################################################################
## Files to copy.
###############################################################################
_module_all_copy_files_src :=
_module_all_copy_files_dst :=

ifneq ("$(LOCAL_COPY_FILES)","")

# Generate a rule to copy all files
# Handle relative/absolute paths
# Handle directory only for destination
$(foreach __pair,$(LOCAL_COPY_FILES), \
	$(eval __w1 := $(firstword $(subst :,$(space),$(__pair)))) \
	$(eval __w2 := $(patsubst $(__w1):%,%,$(__pair))) \
	$(eval __src := $(call copy-get-src-path,$(__w1))) \
	$(eval __dst := $(call copy-get-dst-path$(_mode_suffix),$(__w2))) \
	$(if $(call is-path-dir,$(__dst)), \
		$(eval __dst := $(__dst)$(notdir $(__src))) \
	) \
	$(eval _module_all_copy_files_src += $(__src)) \
	$(eval _module_all_copy_files_dst += $(__dst)) \
	$(eval $(call copy-one-file,$(__src),$(__dst))) \
)

$(foreach __pair,$(LOCAL_COPY_DIRS), \
	$(eval __w1 := $(firstword $(subst :,$(space),$(__pair)))) \
	$(eval __w2 := $(patsubst $(__w1):%,%,$(__pair))) \
	$(eval __src := $(call copy-get-src-path,$(__w1))) \
	$(eval __dst := $(call copy-get-dst-path$(_mode_suffix),$(__w2))) \
	$(eval __files := $(patsubst ./%,%, \
		$(shell cd $(__src); find -type f -o -type l) \
	)) \
	$(foreach __f,$(__files), \
		$(eval __src2 := $(__src)/$(__f)) \
		$(eval __dst2 := $(__dst)/$(__f)) \
		$(eval _module_all_copy_files_src += $(__src2)) \
		$(eval _module_all_copy_files_dst += $(__dst2)) \
		$(eval $(call copy-one-file,$(__src2),$(__dst2))) \
	) \
)


# Add an order-only dependency between sources and prerequisites
# Also make sure bootstrap si done
_module_all_copy_files_prerequisites := \
	$(filter-out $(_module_all_copy_files_src) $(_module_all_copy_files_dst),$(all_prerequisites)) \
	$(_module_bootstrapped_stamp_file)
$(foreach __src,$(_module_all_copy_files_src), \
	$(if $(filter $(__src),$(all_prerequisites)),$(empty), \
		$(eval $(__src): | $(_module_all_copy_files_prerequisites)) \
	) \
)

# Add files to be copied as an order-only dependency (does not force rebuild)
# TODO: is it the correct dependency ?
$(LOCAL_BUILD_MODULE): | $(_module_all_copy_files_dst)

# Remove destination of files to copy from prerequisites
all_prerequisites := $(filter-out $(_module_all_copy_files_dst),$(all_prerequisites))

endif

###############################################################################
## Links to create.
###############################################################################
_module_all_create_links :=

ifneq ("$(LOCAL_CREATE_LINKS)","")

# Generate a rule to create links
$(foreach __pair,$(LOCAL_CREATE_LINKS), \
	$(eval __w1 := $(firstword $(subst :,$(space),$(__pair)))) \
	$(eval __w2 := $(patsubst $(__w1):%,%,$(__pair))) \
	$(eval __name := $($(_mode_prefix)_OUT_STAGING)/$(__w1)) \
	$(eval __target := $(__w2)) \
	$(eval _module_all_create_links += $(__name)) \
	$(eval $(call create-one-link,$(__name),$(__target))) \
)

# Add links to be created as an order-only dependency (does not force rebuild)
# TODO: is it the correct dependency ?
$(LOCAL_BUILD_MODULE): | $(_module_all_create_links)

endif

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

# Do not skip dep checks of QMake modules
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

# Macro to delete a file
# $1 : file to delete
_delete-file = \
	$(if $(wildcard $1), \
		$(if $(call strneq,$(V),0), \
			$(info Deleting $(call path-from-top,$1)) \
		) \
		$(shell rm -f $1) \
	)

_delete-files = $(foreach __f,$1,$(call _delete-file,$(__f)))

# Update list of 'done' files with module file name
# Using sort ensures there is no duplicates in the list
ifeq ("$(patsubst %.done,1,$(LOCAL_MODULE_FILENAME))","1")
  LOCAL_DONE_FILES := $(sort $(LOCAL_DONE_FILES) $(LOCAL_MODULE_FILENAME))
endif

# If not skipping checks of of module built externally, delete some files
# TODO: delete custom targets ?
# TODO: handle absolute file for LOCAL_DONE_FILES
ifeq ("$(skip_ext_checks)","0")
  $(call _delete-files,$(addprefix $(_module_build_dir)/,$(LOCAL_DONE_FILES)))
  ifneq ("$(call is-module-external,$(LOCAL_MODULE))","")
    $(call _delete-file,$(_module_built_stamp_file))
    $(call _delete-file,$(_module_installed_stamp_file))
  endif
endif

###############################################################################
## General rules.
###############################################################################

# Short hand to build module
.PHONY: $(LOCAL_MODULE)
$(LOCAL_MODULE): $(_module_done_stamp_file)

# Add direct dependencies. Mainly used for copy to staging/final dir to get
# everything built for the module
$(LOCAL_MODULE): $(call module-get-depends,$(LOCAL_MODULE))

# Clean module (do NOT put any commands to allow customisation by module)
.PHONY: $(LOCAL_MODULE)-clean
$(LOCAL_MODULE)-clean: $(LOCAL_MODULE)-clean-common

# Clean + delete the build directory
.PHONY: $(LOCAL_MODULE)-dirclean
$(LOCAL_MODULE)-dirclean: $(LOCAL_MODULE)-clean
	$(Q)rm -rf $(PRIVATE_BUILD_DIR)
	+$(call macro-exec-cmd,CMD_POST_DIRCLEAN,empty)

# Common part, delete registered files and directories
# Note: the foreach generates a separate command for each file/dir thanks to
# the $(endl) macro that insert a new line during expansion.
.PHONY: $(LOCAL_MODULE)-clean-common
$(LOCAL_MODULE)-clean-common:
	@echo "Clean: $(PRIVATE_MODULE)"
	$(foreach __f,$(PRIVATE_CLEAN_FILES),$(Q)rm -f $(__f)$(endl))
	$(foreach __d,$(PRIVATE_CLEAN_DIRS),$(Q)rm -rf $(__d)$(endl))

# Display the path of the module
.PHONY: $(LOCAL_MODULE)-path
$(LOCAL_MODULE)-path:
	@echo "$(PRIVATE_MODULE): $(PRIVATE_PATH)"

include $(BUILD_SYSTEM)/classes/codecheck-rules.mk
include $(BUILD_SYSTEM)/classes/codeformat-rules.mk
include $(BUILD_SYSTEM)/classes/genproject-rules.mk
include $(BUILD_SYSTEM)/classes/extra-rules.mk

###############################################################################
## Rule-specific variable definitions.
###############################################################################

$(LOCAL_TARGETS): PRIVATE_ARCH := $(_module_arch)
$(LOCAL_TARGETS): PRIVATE_CC_FLAVOUR := $(_module_cc_flavour)
$(LOCAL_TARGETS): PRIVATE_CC := $(_module_cc)
$(LOCAL_TARGETS): PRIVATE_CXX := $(_module_cxx)
$(LOCAL_TARGETS): PRIVATE_FC := $(_module_fc)
$(LOCAL_TARGETS): PRIVATE_AS := $(_module_as)
$(LOCAL_TARGETS): PRIVATE_AR := $(_module_ar)
$(LOCAL_TARGETS): PRIVATE_LD := $(_module_ld)
$(LOCAL_TARGETS): PRIVATE_NM := $(_module_nm)
$(LOCAL_TARGETS): PRIVATE_STRIP := $(_module_strip)
$(LOCAL_TARGETS): PRIVATE_CPP := $(_module_cpp)
$(LOCAL_TARGETS): PRIVATE_RANLIB := $(_module_ranlib)
$(LOCAL_TARGETS): PRIVATE_OBJCOPY := $(_module_objcopy)
$(LOCAL_TARGETS): PRIVATE_OBJDUMP := $(_module_objdump)
$(LOCAL_TARGETS): PRIVATE_WINDRES := $(_module_windres)
$(LOCAL_TARGETS): PRIVATE_PATH := $(LOCAL_PATH)
$(LOCAL_TARGETS): PRIVATE_MODULE := $(LOCAL_MODULE)
$(LOCAL_TARGETS): PRIVATE_MODULE_FILENAME := $(LOCAL_MODULE_FILENAME)
$(LOCAL_TARGETS): PRIVATE_MODULE_CLASS := $(LOCAL_MODULE_CLASS)
$(LOCAL_TARGETS): PRIVATE_DESCRIPTION := $(LOCAL_DESCRIPTION)
$(LOCAL_TARGETS): PRIVATE_BUILD_DIR := $(_module_build_dir)
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES := $(LOCAL_CLEAN_FILES)
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(_module_all_stamp_files)
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(_module_all_copy_files_dst)
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(_module_all_create_links)
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(LOCAL_BUILD_MODULE)
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(_module_revision_file)
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(_module_revision_h_file)
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(_module_build_config_file)
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(_module_autoconf_file)
$(LOCAL_TARGETS): PRIVATE_CLEAN_DIRS := $(LOCAL_CLEAN_DIRS)
$(LOCAL_TARGETS): PRIVATE_MODE := $(_mode_prefix)
$(LOCAL_TARGETS): PRIVATE_MODE_IS_HOST := $(_mode_host)
$(LOCAL_TARGETS): PRIVATE_REV_FILE := $(_module_revision_file)
$(LOCAL_TARGETS): PRIVATE_REV_FILE_H := $(_module_revision_h_file)
$(LOCAL_TARGETS): PRIVATE_SRC_FILES := $(LOCAL_SRC_FILES)
$(LOCAL_TARGETS): PRIVATE_GENERATED_SRC_FILES := $(LOCAL_GENERATED_SRC_FILES)
$(LOCAL_TARGETS): PRIVATE_NO_UNDEFINED := $(if $(_mode_host),1,$(TARGET_NO_UNDEFINED))

$(LOCAL_TARGETS): PRIVATE_ARCHIVE := $(_module_archive_file)
$(LOCAL_TARGETS): PRIVATE_ARCHIVE_UNPACK_DIR := $(_module_build_dir)
$(LOCAL_TARGETS): PRIVATE_ARCHIVE_SUBDIR := $(LOCAL_ARCHIVE_SUBDIR)
$(LOCAL_TARGETS): PRIVATE_ARCHIVE_PATCHES := $(LOCAL_ARCHIVE_PATCHES)

# Setup custom variables.
# The first loop is to clear content for current module.
# The second loop uses += to accumulate values from different imported modules.
private-custom-clear = $(eval $(LOCAL_TARGETS): PRIVATE_CUSTOM_$1 :=)
private-custom-set = $(eval $(LOCAL_TARGETS): PRIVATE_CUSTOM_$1 := $2)
$(call var-list-foreach,$(imported_CUSTOM_VARIABLES),private-custom-clear)
$(call var-list-foreach,$(imported_CUSTOM_VARIABLES),private-custom-set)

# This is for police hooks
$(LOCAL_TARGETS): export MODULE_NAME := $(LOCAL_MODULE)

###############################################################################
###############################################################################

# Each module class can fill one of these to setup default commands and internal
# pre/post hooks
_module_msg := $(if $(_mode_host),Host )Generic
_module_cmd_prefix :=

_module_def_cmd_bootstrap := empty
_module_def_cmd_configure := empty
_module_def_cmd_build := empty
_module_def_cmd_install := empty
_module_def_cmd_clean := empty

_module_hook_pre_bootstrap := empty
_module_hook_post_bootstrap := empty
_module_hook_pre_configure := empty
_module_hook_post_configure := empty
_module_hook_pre_build := empty
_module_hook_post_build := empty
_module_hook_pre_install := empty
_module_hook_post_install := empty
_module_hook_pre_clean := empty
_module_hook_post_clean := empty

# Make sure module class is not empty to avoid infinite loop
ifeq ("$(LOCAL_MODULE_CLASS)","")
$(error $(LOCAL_MODULE): LOCAL_MODULE_CLASS is empty)
endif
include $(BUILD_SYSTEM)/classes/$(LOCAL_MODULE_CLASS)/rules.mk

endif
