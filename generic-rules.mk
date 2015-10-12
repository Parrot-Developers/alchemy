###############################################################################
## @file generic-rules.mk
## @author Y.M. Morgan
## @date 2013/24/13
##
## Build a module using generic rules.
###############################################################################

# Name of files indicating steps done
# Using version allow to switch without having some dependencies troubles
ifneq ("$(LOCAL_ARCHIVE_VERSION)","")
  configured_file := $(build_dir)/$(LOCAL_MODULE)-$(LOCAL_ARCHIVE_VERSION).configured
  built_file := $(build_dir)/$(LOCAL_MODULE)-$(LOCAL_ARCHIVE_VERSION).built
  installed_file := $(build_dir)/$(LOCAL_MODULE)-$(LOCAL_ARCHIVE_VERSION).installed
  post_installed_file := $(build_dir)/$(LOCAL_MODULE)-$(LOCAL_ARCHIVE_VERSION).post-installed
else
  configured_file := $(build_dir)/$(LOCAL_MODULE).configured
  built_file := $(build_dir)/$(LOCAL_MODULE).built
  installed_file := $(build_dir)/$(LOCAL_MODULE).installed
  post_installed_file := $(build_dir)/$(LOCAL_MODULE).post-installed
endif

# Where the source will actually be found once unpacked (or copied)
ifneq ("$(LOCAL_ARCHIVE)","")
  src_dir := $(unpack_dir)/$(LOCAL_ARCHIVE_SUBDIR)
else ifeq ("$(LOCAL_COPY_TO_BUILD_DIR)","1")
  src_dir := $(build_dir)
else
  src_dir := $(LOCAL_PATH)
endif

# Where the package will be configured and built
# TODO: try to build outside source even for unpacked archives
ifneq ("$(LOCAL_ARCHIVE)","")
  ifeq ("$(generic-build-out-of-src)","0")
    obj_dir := $(src_dir)
  else
    obj_dir := $(build_dir)/obj
  endif
else
  obj_dir := $(build_dir)/obj
endif

# Delete some additionnal 'done' files if a skip of external checks is not done
ifeq ("$(skip_ext_checks)","0")
$(call delete-one-done-file,$(built_file))
$(call delete-one-done-file,$(installed_file))
endif

# Display a message
# $1 : message
__generic-msg = \
	$(call print-banner2,$(PRIVATE_MSG),$(PRIVATE_MODULE),$1)

###############################################################################
## Rules.
## Note : use '+' to make sure sub-make is properly managed, this avoid:
## warning: jobserver unavailable: using -j1.  Add `+' to parent make rule.
###############################################################################

# Make sure all prerequisites files are generated first
# But do NOT force recompilation (order only)
$(configured_file): | $(all_prerequisites) $(all_depends_build_filename) $(all_link_libs_filenames)

# If an autoconf file has changed, restart at the configure step
$(configured_file): $(all_autoconf)

# Restart build if any of dependencies have changed
$(built_file): $(all_depends_build_filename) $(all_link_libs_filenames)

# Configuration
# If the user makefile is changed, restart at the configure step
$(configured_file): $(LOCAL_PATH)/$(USER_MAKEFILE_NAME) $(unpacked_file)
	$(call __generic-msg,Configuring)
	@mkdir -p $(PRIVATE_OBJ_DIR)
	+$(if $(PRIVATE_HOOK_PRE_CONFIGURE),$(call $(PRIVATE_HOOK_PRE_CONFIGURE)))
	+$(call macro-exec-cmd,$(PRIVATE_CMD_PREFIX)_CMD_CONFIGURE,$(PRIVATE_DEFAULT_CMD_CONFIGURE))
	+$(call macro-exec-cmd,$(PRIVATE_CMD_PREFIX)_CMD_POST_CONFIGURE,empty)
	+$(if $(PRIVATE_HOOK_POST_CONFIGURE),$(call $(PRIVATE_HOOK_POST_CONFIGURE)))
	@mkdir -p $(dir $@)
	@touch $@

# Build
$(built_file): $(configured_file)
	$(call __generic-msg,Building)
	@mkdir -p $(PRIVATE_OBJ_DIR)
	+$(if $(PRIVATE_HOOK_PRE_BUILD),$(call $(PRIVATE_HOOK_PRE_BUILD)))
	+$(call macro-exec-cmd,$(PRIVATE_CMD_PREFIX)_CMD_BUILD,$(PRIVATE_DEFAULT_CMD_BUILD))
	+$(call macro-exec-cmd,$(PRIVATE_CMD_PREFIX)_CMD_POST_BUILD,empty)
	+$(if $(PRIVATE_HOOK_POST_BUILD),$(call $(PRIVATE_HOOK_POST_BUILD)))
	@mkdir -p $(dir $@)
	@touch $@

# Installation
$(installed_file): $(built_file)
	$(call __generic-msg,Installing)
	+$(if $(PRIVATE_HOOK_PRE_INSTALL),$(call $(PRIVATE_HOOK_PRE_INSTALL)))
	+$(call macro-exec-cmd,$(PRIVATE_CMD_PREFIX)_CMD_INSTALL,$(PRIVATE_DEFAULT_CMD_INSTALL))
	@mkdir -p $(dir $@)
	@touch $@

$(post_installed_file): $(installed_file)
	+$(call macro-exec-cmd,$(PRIVATE_CMD_PREFIX)_CMD_POST_INSTALL,empty)
	+$(if $(PRIVATE_HOOK_POST_INSTALL),$(call $(PRIVATE_HOOK_POST_INSTALL)))
	@mkdir -p $(dir $@)
	@touch $@

# Done (copy license files in obj dir if different from src dir)
$(LOCAL_BUILD_MODULE): $(post_installed_file)
	@mkdir -p $(dir $@)
ifneq ("$(src_dir)","$(obj_dir)")
	$(call copy-license-files,$(PRIVATE_PATH),$(PRIVATE_OBJ_DIR))
endif
	@$(call generate-last-revision-file,$(PRIVATE_MODULE),$(PRIVATE_REV_FILE))
	@touch $@

# Clean targets additional commands
$(LOCAL_MODULE)-clean:
	+$(if $(PRIVATE_HOOK_PRE_CLEAN),$(call $(PRIVATE_HOOK_PRE_CLEAN)))
	+$(call macro-exec-cmd,$(PRIVATE_CMD_PREFIX)_CMD_CLEAN,$(PRIVATE_DEFAULT_CMD_CLEAN))
	+$(call macro-exec-cmd,$(PRIVATE_CMD_PREFIX)_CMD_POST_CLEAN,empty)
	+$(if $(PRIVATE_HOOK_POST_CLEAN),$(call $(PRIVATE_HOOK_POST_CLEAN)))

###############################################################################
## Rule-specific variable definitions.
###############################################################################

# clean targets additional variables
# To NOT put build dir in PRIVATE_CLEAN_DIRS
# we need to call some makefiles during our custom clean
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(post_installed_file)
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(installed_file)
$(LOCAL_TARGETS): PRIVATE_CLEAN_FILES += $(built_file)

# We don't create target-specific variables for macros because it does not
# work when created with 'define ... endef'. They will be accessed directly
# from module database
$(LOCAL_TARGETS): PRIVATE_SRC_DIR := $(src_dir)
$(LOCAL_TARGETS): PRIVATE_OBJ_DIR := $(obj_dir)

# Commands
$(LOCAL_TARGETS): PRIVATE_MSG := Generic
$(LOCAL_TARGETS): PRIVATE_CMD_PREFIX := GENERIC
$(LOCAL_TARGETS): PRIVATE_DEFAULT_CMD_CONFIGURE := empty
$(LOCAL_TARGETS): PRIVATE_DEFAULT_CMD_BUILD := empty
$(LOCAL_TARGETS): PRIVATE_DEFAULT_CMD_INSTALL := empty
$(LOCAL_TARGETS): PRIVATE_DEFAULT_CMD_CLEAN := empty

# Internal hooks to be applied before/after steps.
$(LOCAL_TARGETS): PRIVATE_HOOK_PRE_CONFIGURE :=
$(LOCAL_TARGETS): PRIVATE_HOOK_POST_CONFIGURE :=
$(LOCAL_TARGETS): PRIVATE_HOOK_PRE_BUILD :=
$(LOCAL_TARGETS): PRIVATE_HOOK_POST_BUILD :=
$(LOCAL_TARGETS): PRIVATE_HOOK_PRE_INSTALL :=
$(LOCAL_TARGETS): PRIVATE_HOOK_POST_INSTALL :=
$(LOCAL_TARGETS): PRIVATE_HOOK_PRE_CLEAN :=
$(LOCAL_TARGETS): PRIVATE_HOOK_POST_CLEAN :=

