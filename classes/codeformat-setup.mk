###############################################################################
## @file classes/codeformat-setup.mk
## @author N. Brulez
## @date 2018/11/16
##
## Setup code formatting.
###############################################################################

###############################################################################
## Default formatters
###############################################################################

_default_codeformat_c := clang-format
_default_codeformat_cxx := clang-format
_default_codeformat_objc := clang-format
_default_codeformat_python := pep8

###############################################################################
## Get the available format targets for a given module.
## $1: module name (can be all)
###############################################################################
codeformat-get-targets = $(strip \
	$1-codeformat \
	$(addprefix $1-codeformat-,c cxx objc python) \
)

###############################################################################
## Get the script to use for code formatting.
## $1 : language (in lower case)
## $2 : language (in uppercase case)
##
## If LOCAL_CODEFORMAT_XXX is not empty and is a valid script file, use it
## otherwise, use a wrapper script for the language.
###############################################################################
_codeformat-get-script = $(strip \
	$(if $(and $(LOCAL_CODEFORMAT_$2),$(wildcard $(LOCAL_CODEFORMAT_$2))), \
		$(LOCAL_CODEFORMAT_$2) \
		, \
		$(BUILD_SYSTEM)/scripts/codeformat/codeformat-$1.sh \
	))

###############################################################################
## Get the formatter to use for code formatting.
## $1 : language (in lower case)
## $2 : language (in uppercase case)
##
## If LOCAL_CODEFORMAT_XXX is not empty and is a valid script file, assume empty
## otherwise, LOCAL_CODEFORMAT_XXX is the formatter to use.
## If LOCAL_CODEFORMAT_XXX is empty, use a default formatter for the language.
###############################################################################
_codeformat-get-formatter = $(strip \
	$(if $(and $(LOCAL_CODEFORMAT_$2),$(wildcard $(LOCAL_CODEFORMAT_$2))), \
		$(empty) \
		, \
		$(if $(LOCAL_CODEFORMAT_$2), \
			$(LOCAL_CODEFORMAT_$2) \
			, \
			$(_default_codeformat_$1) \
		) \
	))

###############################################################################
## Generate rules for code formatting.
## $1 : language (in lower case)
## $2 : language (in uppercase case)
##
## Put ARGS and FILES between quotes to pass space then as 1 single shell arg
###############################################################################
define _codeformat-gen-rules
_codeformat-script := $(call _codeformat-get-script,$1,$2)
_codeformat-formatter := $(call _codeformat-get-formatter,$1,$2)
$(LOCAL_MODULE)-codeformat-$1: PRIVATE_CODEFORMAT_SCRIPT := $$(_codeformat-script)
$(LOCAL_MODULE)-codeformat-$1: PRIVATE_CODEFORMAT_FORMATTER := $$(_codeformat-formatter)
$(LOCAL_MODULE)-codeformat-$1: PRIVATE_CODEFORMAT_ARGS := $(LOCAL_CODEFORMAT_$2_ARGS)
$(LOCAL_MODULE)-codeformat-$1: PRIVATE_CODEFORMAT_FILES := $(_codeformat_$1_files)
.PHONY: $(LOCAL_MODULE)-codeformat-$1
$(LOCAL_MODULE)-codeformat-$1:
	$$(if $$(PRIVATE_CODEFORMAT_FILES), \
		$$(if $$(call streq,$$(PRIVATE_CODEFORMAT_FORMATTER),none), \
			@echo "$$(PRIVATE_MODULE): Format of '$1' files disabled" \
			, \
			@echo "$$(PRIVATE_MODULE): Formatting '$1' files..."$$(endl) \
			$(Q) $$(PRIVATE_CODEFORMAT_SCRIPT) \
				"$$(PRIVATE_CODEFORMAT_FORMATTER)" \
				"$$(PRIVATE_CODEFORMAT_ARGS)" \
				"$$(PRIVATE_CODEFORMAT_FILES)" \
				"$$(PRIVATE_PATH)" || true \
		) \
	)
$(LOCAL_MODULE)-codeformat: $(LOCAL_MODULE)-codeformat-$1
endef
