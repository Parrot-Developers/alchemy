###############################################################################
## @file classes/codecheck-setup.mk
## @author Y.M. Morgan
## @date 2016/06/12
##
## Setup codecheck.
###############################################################################

###############################################################################
## Default checkers
###############################################################################

_default_codecheck_as := none
_default_codecheck_c := linux clang-format
_default_codecheck_cxx := clang-format
_default_codecheck_objc := none
_default_codecheck_objcpp := none
_default_codecheck_vala := valastyle
_default_codecheck_python := pep8

###############################################################################
## Get the available codecheck targets for a given module.
## $1: module name (can be all)
###############################################################################
codecheck-get-targets = $(strip \
	$1-codecheck \
	$(addprefix $1-codecheck-,as c cxx objc objcpp vala python) \
)

###############################################################################
## Get the script to use for code check.
## $1 : language (in lower case)
## $2 : language (in uppercase case)
##
## If LOCAL_CODECHECK_XXX is not empty and is a valid script file, use it
## otherwise, use a wrapper script for the language.
###############################################################################
_codecheck-get-script = $(strip \
	$(if $(and $(LOCAL_CODECHECK_$2),$(wildcard $(LOCAL_CODECHECK_$2))), \
		$(LOCAL_CODECHECK_$2) \
		, \
		$(BUILD_SYSTEM)/scripts/codecheck/codecheck-$1.sh \
	))

###############################################################################
## Get the checker to use for code check.
## $1 : language (in lower case)
## $2 : language (in uppercase case)
##
## If LOCAL_CODECHECK_XXX is not empty and is a valid script file, assume empty
## otherwise, LOCAL_CODECHECK_XXX is the checker to use.
## If LOCAL_CODECHECK_XXX is empty, use a default checker for the language.
###############################################################################
_codecheck-get-checker = $(strip \
	$(if $(and $(LOCAL_CODECHECK_$2),$(wildcard $(LOCAL_CODECHECK_$2))), \
		$(empty) \
		, \
		$(if $(LOCAL_CODECHECK_$2), \
			$(LOCAL_CODECHECK_$2) \
			, \
			$(_default_codecheck_$1) \
		) \
	))

###############################################################################
## Generate rules for code check.
## $1 : language (in lower case)
## $2 : language (in uppercase case)
##
## Put ARGS and FILES between quotes to pass space then as 1 single shell arg
###############################################################################
define _codecheck-gen-rules
_codecheck-script := $(call _codecheck-get-script,$1,$2)
_codecheck-checker := $(call _codecheck-get-checker,$1,$2)
$(LOCAL_MODULE)-codecheck-$1: PRIVATE_CODECHECK_SCRIPT := $$(_codecheck-script)
$(LOCAL_MODULE)-codecheck-$1: PRIVATE_CODECHECK_CHECKER := $$(_codecheck-checker)
$(LOCAL_MODULE)-codecheck-$1: PRIVATE_CODECHECK_ARGS := $(LOCAL_CODECHECK_$2_ARGS)
$(LOCAL_MODULE)-codecheck-$1: PRIVATE_CODECHECK_FILES := $(_codecheck_$1_files)
.PHONY: $(LOCAL_MODULE)-codecheck-$1
$(LOCAL_MODULE)-codecheck-$1:
	$$(if $$(PRIVATE_CODECHECK_FILES), \
		$$(if $$(call streq,$$(PRIVATE_CODECHECK_CHECKER),none), \
			@echo "$$(PRIVATE_MODULE): Check of '$1' files disabled" \
			, \
			@echo "$$(PRIVATE_MODULE): Checking '$1' files..."$$(endl) \
			$(Q) $$(PRIVATE_CODECHECK_SCRIPT) \
				"$$(PRIVATE_CODECHECK_CHECKER)" \
				"$$(PRIVATE_CODECHECK_ARGS)" \
				"$$(PRIVATE_CODECHECK_FILES)" \
				"$$(PRIVATE_PATH)" || true \
		) \
	)
$(LOCAL_MODULE)-codecheck: $(LOCAL_MODULE)-codecheck-$1
endef
