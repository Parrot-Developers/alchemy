###############################################################################
## @file classes/GENERIC/rules.mk
## @author Y.M. Morgan
## @date 2016/03/20
##
## Rules for GENERIC modules.
###############################################################################

# Where the source will actually be found once unpacked (or copied)
ifneq ("$(_module_archive_file)","")
  _generic_src_dir := $(_module_build_dir)/$(LOCAL_ARCHIVE_SUBDIR)
else ifeq ("$(LOCAL_COPY_TO_BUILD_DIR)","1")
  _generic_src_dir := $(_module_build_dir)
else
  _generic_src_dir := $(LOCAL_PATH)
endif

# Where the package will be configured and built
# Because autootools are widely used for generic build to not try to support
# out ouf source build for unpacked autotools archives
# TODO: try to build outside source even for unpacked autotools archives
ifneq ("$(_module_archive_file)","")
  ifeq ("$(LOCAL_MODULE_CLASS)","AUTOTOOLS")
    _generic_obj_dir := $(_generic_src_dir)
  else
    _generic_obj_dir := $(_module_build_dir)/obj
  endif
else
  _generic_obj_dir := $(_module_build_dir)/obj
endif

###############################################################################
# Generate header file with revision
# The 'sed' command will remove leading spaces on each lines
# If we have make 4.0, create the file internally. This requires the 'mkdir' to
# be done in another rule to guarantee execution order
###############################################################################

ifneq ("$(_module_revision_h_file)","")

$(_module_revision_h_file): .FORCE | $(_module_revision_h_file)-dir
ifeq ("$(MAKE_HAS_FILE_FUNC)","1")
	$(file > $@.tmp,$(_generic-get-revision-h))
else
	@echo -e "$(call escape-echo,$(_generic-get-revision-h))" > $@.tmp
endif
	@sed -i.bak -e 's/^ *//' $@.tmp && rm -f $@.tmp.bak
	$(call update-file-if-needed,$@,$@.tmp)

.PHONY: $(_module_revision_h_file)-dir
$(_module_revision_h_file)-dir:
	@mkdir -p $(dir $@)

endif

###############################################################################
###############################################################################

ifneq ("$(_module_autoconf_file)","")

$(_module_autoconf_file): PRIVATE_BUILD_CONFIG_FILE := $(_module_build_config_file)

ifneq ("$(wildcard $(_module_orig_config_file))","")
# Original config file exists, copy it with optional sed files applied
$(_module_autoconf_file): $(_module_orig_config_file)
	$(call __config-apply-sed,$(PRIVATE_MODULE),$(PRIVATE_BUILD_CONFIG_FILE),$<)
	@$(call generate-autoconf-file,$(PRIVATE_BUILD_CONFIG_FILE),$@)
else
# No Original config file, simply create an empty one in build dir
$(_module_autoconf_file):
	@mkdir -p $(dir $(PRIVATE_BUILD_CONFIG_FILE))
	@touch $(PRIVATE_BUILD_CONFIG_FILE)
	@$(call generate-autoconf-file,$(PRIVATE_BUILD_CONFIG_FILE),$@)
endif

endif

###############################################################################
# Force unpack if patches are changed to make sure they are correctly applied
###############################################################################

# TODO: do we really need the license also in archive subdir ?
$(_module_unpacked_stamp_file): $(_module_archive_file) $(addprefix $(LOCAL_PATH)/,$(_module_archive_patches))
ifneq ("$(_module_archive_file)","")
	$(call _generic-msg,Unpacking)
	@mkdir -p $(PRIVATE_ARCHIVE_UNPACK_DIR)
	+$(call macro-exec-cmd,ARCHIVE_CMD_UNPACK,_generic-def-cmd-unpack)
	$(call copy-license-files,$(PRIVATE_PATH),$(PRIVATE_ARCHIVE_UNPACK_DIR)/$(PRIVATE_ARCHIVE_SUBDIR))
endif
	$(call copy-license-files,$(PRIVATE_PATH),$(PRIVATE_BUILD_DIR))
	@mkdir -p $(dir $@)
	@touch $@

# TODO: ARCHIVE_CMD_POST_UNPACK is always called here for compatibility
$(_module_patched_stamp_file): $(_module_unpacked_stamp_file)
ifneq ("$(_module_archive_patches)","")
	$(call _generic-msg,Patching)
	$(_generic-apply-patches)
endif
	+$(call macro-exec-cmd,ARCHIVE_CMD_POST_UNPACK,empty)
	@mkdir -p $(dir $@)
	@touch $@

###############################################################################
###############################################################################

$(_module_bootstrapped_stamp_file): $(_module_patched_stamp_file)
	+$(call _generic-exec-step,BOOTSTRAP,Bootstrapping)
	@mkdir -p $(dir $@)
	@touch $@

$(_module_configured_stamp_file): $(_module_bootstrapped_stamp_file)
	+$(call _generic-exec-step,CONFIGURE,Configuring)
	@mkdir -p $(dir $@)
	@touch $@

# Make sure that the 'build-filename' file will be created for external module
# TODO warn if file was not created ?
$(_module_built_stamp_file): $(_module_configured_stamp_file) $(addprefix $(LOCAL_PATH)/,$(LOCAL_EXTRA_DEPENDENCIES))
	+$(call _generic-exec-step,BUILD,Building)
	@mkdir -p $(dir $@)
	$(if $(call is-module-external,$(PRIVATE_MODULE)), \
		@touch $(call module-get-build-filename,$(PRIVATE_MODULE)) \
	)
	@touch $@

$(_module_installed_stamp_file): $(_module_built_stamp_file)
	+$(call macro-exec-cmd,CMD_PRE_INSTALL,empty)
	+$(call _generic-exec-step,INSTALL,Installing)
	@$(call generate-last-revision-file,$(PRIVATE_MODULE),$(PRIVATE_REV_FILE))
	@mkdir -p $(dir $@)
	@touch $@

$(_module_done_stamp_file): $(_module_installed_stamp_file)
	@mkdir -p $(dir $@)
	@touch $@

.PHONY: $(LOCAL_MODULE)-clean-generic
$(LOCAL_MODULE)-clean-generic: $(LOCAL_MODULE)-clean-common
	+$(call _generic-exec-step,CLEAN,$(empty))
	$(call delete-license-files,$(PRIVATE_BUILD_DIR))

$(LOCAL_MODULE)-clean: $(LOCAL_MODULE)-clean-generic

###############################################################################
###############################################################################

# Patching may require copy in build directory
$(_module_patched_stamp_file): $(_module_copy_to_build_dir_dst_files)

# Bootstrapping may requires all prerequisites
# But do NOT force recompilation (order only)
$(_module_bootstrapped_stamp_file): | $(all_prerequisites)

# Make sure all prerequisites files are generated first
# But do NOT force recompilation (order only)
# TODO: only for external modules
$(_module_configured_stamp_file): | $(all_depends_installed_stamp) $(all_link_libs_filenames)

# If the user makefile is changed, restart at the configure step
ifneq ("$(wildcard $(LOCAL_PATH)/$(USER_MAKEFILE_NAME))","")
$(_module_configured_stamp_file): $(LOCAL_PATH)/$(USER_MAKEFILE_NAME)
endif

# If an autoconf file has changed, restart at the configure step
$(_module_configured_stamp_file): $(all_autoconf)

# Restart build if any of dependencies have changed
$(_module_built_stamp_file): $(all_depends_installed_stamp) $(all_link_libs_filenames)

# Insert build module between configured and built steps
$(LOCAL_BUILD_MODULE): $(_module_configured_stamp_file)
$(_module_built_stamp_file): $(LOCAL_BUILD_MODULE)

# This will force to recheck this module if one of its dependencies is changed.
$(LOCAL_BUILD_MODULE): $(all_depends_installed_stamp)
$(LOCAL_CUSTOM_TARGETS): $(all_depends_installed_stamp)

# Prerequisites that are not ours
all_external_prerequisites := $(filter-out \
	$(LOCAL_CUSTOM_TARGETS) \
	$(LOCAL_PREREQUISITES) \
	$(LOCAL_EXPORT_PREREQUISITES), $(all_prerequisites))
$(LOCAL_CUSTOM_TARGETS): | $(all_external_prerequisites)
$(LOCAL_PREREQUISITES): | $(all_external_prerequisites)
$(LOCAL_EXPORT_PREREQUISITES): | $(all_external_prerequisites)

# This explicit rule avoids dependency error when the module has nothing to build
# (prebuilt, sdk, custom...)
$(LOCAL_BUILD_MODULE):

###############################################################################
###############################################################################

$(LOCAL_TARGETS): PRIVATE_SRC_DIR := $(_generic_src_dir)
$(LOCAL_TARGETS): PRIVATE_OBJ_DIR := $(_generic_obj_dir)

# Commands
$(LOCAL_TARGETS): PRIVATE_MSG := $(_module_msg)
$(LOCAL_TARGETS): PRIVATE_CMD_PREFIX := $(_module_cmd_prefix)
$(LOCAL_TARGETS): PRIVATE_DEF_CMD_BOOTSTRAP := $(_module_def_cmd_bootstrap)
$(LOCAL_TARGETS): PRIVATE_DEF_CMD_CONFIGURE := $(_module_def_cmd_configure)
$(LOCAL_TARGETS): PRIVATE_DEF_CMD_BUILD := $(_module_def_cmd_build)
$(LOCAL_TARGETS): PRIVATE_DEF_CMD_INSTALL := $(_module_def_cmd_install)
$(LOCAL_TARGETS): PRIVATE_DEF_CMD_CLEAN := $(_module_def_cmd_clean)

# Internal hooks to be applied before/after steps.
$(LOCAL_TARGETS): PRIVATE_HOOK_PRE_BOOTSTRAP := $(_module_hook_pre_bootstrap)
$(LOCAL_TARGETS): PRIVATE_HOOK_POST_BOOTSTRAP := $(_module_hook_post_bootstrap)
$(LOCAL_TARGETS): PRIVATE_HOOK_PRE_CONFIGURE := $(_module_hook_pre_configure)
$(LOCAL_TARGETS): PRIVATE_HOOK_POST_CONFIGURE := $(_module_hook_post_configure)
$(LOCAL_TARGETS): PRIVATE_HOOK_PRE_BUILD := $(_module_hook_pre_build)
$(LOCAL_TARGETS): PRIVATE_HOOK_POST_BUILD := $(_module_hook_post_build)
$(LOCAL_TARGETS): PRIVATE_HOOK_PRE_INSTALL := $(_module_hook_pre_install)
$(LOCAL_TARGETS): PRIVATE_HOOK_POST_INSTALL := $(_module_hook_post_install)
$(LOCAL_TARGETS): PRIVATE_HOOK_PRE_CLEAN := $(_module_hook_pre_clean)
$(LOCAL_TARGETS): PRIVATE_HOOK_POST_CLEAN := $(_module_hook_post_clean)
