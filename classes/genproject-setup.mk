###############################################################################
## @file classes/genproject-setup.mk
## @author M. Girard
## @date 2018/05/20
##
## Setup genproject.
###############################################################################

###############################################################################
## Get the IDE list available
###############################################################################
genproject-get-ides = eclipse qtcreator jsondb vscode

###############################################################################
## Get the available genproject targets for a given module.
## $1: module name (can be all)
###############################################################################
genproject-get-targets = $(strip \
	$1-genproject \
	$(addprefix $1-genproject-,$(genproject-get-ides)) \
)

###############################################################################
## Generate rules for genproject.
## $1 : ide
##
## Put ARGS and FILES between quotes to pass space then as 1 single shel arg
###############################################################################
define _genproject-gen-rules
.PHONY: $(LOCAL_MODULE)-genproject-$1
$(LOCAL_MODULE)-genproject-$1: dump-xml
	@echo "$$(PRIVATE_MODULE): Genproject for '$1' '$$(DUMP_DATABASE_XML_FILE)' '$$(PRIVATE_MODULE)'"
	$(Q) $(BUILD_SYSTEM)/scripts/genproject/genproject.py $1 $$(DUMP_DATABASE_XML_FILE) $$(PRIVATE_MODULE)
$(LOCAL_MODULE)-genproject: $(LOCAL_MODULE)-genproject-$1
endef
