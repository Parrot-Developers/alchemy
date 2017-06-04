###############################################################################
## @file classes/GENERIC/setup.mk
## @author Y.M. Morgan
## @date 2016/03/20
##
## Setup GENERIC modules.
###############################################################################

# Display a message
# $1 : message
_generic-msg = \
	$(call print-banner2,$(PRIVATE_MSG),$(PRIVATE_MODULE),$1)

define _generic-def-cmd-unpack
	$(if $(call strneq,$(realpath $(PRIVATE_ARCHIVE_UNPACK_DIR)/$(PRIVATE_ARCHIVE_SUBDIR)),$(realpath $(PRIVATE_ARCHIVE_UNPACK_DIR))), \
		$(Q) rm -rf $(PRIVATE_ARCHIVE_UNPACK_DIR)/$(PRIVATE_ARCHIVE_SUBDIR) \
	)
	$(if $(patsubst %.zip,,$(PRIVATE_ARCHIVE)), \
		$(Q) $(TAR) -C $(PRIVATE_ARCHIVE_UNPACK_DIR) -xf $(PRIVATE_ARCHIVE) \
		, \
		$(Q) unzip -oq -d $(PRIVATE_ARCHIVE_UNPACK_DIR) $(PRIVATE_ARCHIVE) \
	)
endef

define _generic-apply-patches
	$(Q) $(BUILD_SYSTEM)/scripts/apply-patches.sh \
		$(PRIVATE_ARCHIVE_UNPACK_DIR)/$(PRIVATE_ARCHIVE_SUBDIR) \
		$(PRIVATE_PATH) \
		$(PRIVATE_ARCHIVE_PATCHES)
endef

# $1 : step (CONFIGURE, BUILD...)
# $2 : message
define _generic-exec-step
	$(if $(call macro-has-cmd,$(PRIVATE_CMD_PREFIX)CMD_$1,$(PRIVATE_DEF_CMD_$1)), \
		$(if $2,$(call _generic-msg,$2)) \
	)
	@mkdir -p $(PRIVATE_OBJ_DIR)
	$(if $(PRIVATE_HOOK_PRE_$1),$(call $(PRIVATE_HOOK_PRE_$1)))
	$(call macro-exec-cmd,$(PRIVATE_CMD_PREFIX)CMD_$1,$(PRIVATE_DEF_CMD_$1))
	$(call macro-exec-cmd,$(PRIVATE_CMD_PREFIX)CMD_POST_$1,empty)
	$(if $(PRIVATE_HOOK_POST_$1),$(call $(PRIVATE_HOOK_POST_$1)))
endef

_generic-get-revision-h = \
	$(eval __var := $(call module-get-define,$(PRIVATE_MODULE))) \
	$(eval __val1 := $(call module-get-revision,$(PRIVATE_MODULE))) \
	$(eval __val2 := $(call module-get-revision-describe,$(PRIVATE_MODULE))) \
	\#define ALCHEMY_REVISION_$(__var) "$(__val1)"$(endl) \
	\#define ALCHEMY_REVISION_DESCRIBE_$(__var) "$(__val2)"$(endl)
