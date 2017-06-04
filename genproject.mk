###############################################################################
## @file classes/genproject-rules.mk
## @author Y.M. Morgan
## @date 2018/07/16
##
## Rules for genproject.
###############################################################################

# Available generators
GENPROJECT_KINDS := eclipse qtcreator jsondb vscode

define genproject-help-msg
	@echo "--------------------"
	@echo "Arguments should be given in environement/makefile variable GENPROJECT_ARGS"
	@echo "Modules or directories should be given in environement/makefile variable GENPROJECT_MODULES_OR_DIRS"
endef

# $1: kind
define genproject-gen-rule
.PHONY: genproject-$1
genproject-$1: dump-xml
	$(if $(GENPROJECT_MODULES_OR_DIRS),$(empty),$(genproject-help-msg); exit 2)
	$(BUILD_SYSTEM)/scripts/genproject/genproject.py \
		$(GENPROJECT_ARGS) \
		$1 $(DUMP_DATABASE_XML_FILE) \
		$(GENPROJECT_MODULES_OR_DIRS)
endef

# Generate rules
$(foreach __kind,$(GENPROJECT_KINDS), \
	$(eval $(call genproject-gen-rule,$(__kind))) \
)

.PHONY: genproject-help
genproject-help:
	$(Q) $(BUILD_SYSTEM)/scripts/genproject/genproject.py --help
	$(genproject-help-msg)
