###############################################################################
## @file classes/META_PACKAGE/rules.mk
## @author Y.M. Morgan
## @date 2016/03/20
##
## Rules for META_PACKAGE modules.
###############################################################################

_module_msg := $(if $(_mode_host),Host )MetaPackage

include $(BUILD_SYSTEM)/classes/GENERIC/rules.mk

# Add a meta package dependency
# $1 : module name
# $2 : dependency name
define _meta-package-dep
$1: $2
$1-clean: $2-clean
$1-dirclean: $2-dirclean
$1-codecheck: $2-codecheck
$1-doc: $2-doc
$1-cloc: $2-cloc
endef

# Add deps for build, clean, dirclean
$(foreach __mod,$(call module-get-config-depends,$(LOCAL_MODULE)), \
	$(eval $(call _meta-package-dep,$(LOCAL_MODULE),$(__mod))) \
)
