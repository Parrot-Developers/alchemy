###############################################################################
## @file config-defs.mk
## @author Y.M. Morgan
## @date 2012/07/09
##
## Configuration management, defines.
###############################################################################

# TARGET_xxx variables to pass as environment for confwrapper
CONFWRAPPER_ENV := \
	TARGET_PRODUCT="$(TARGET_PRODUCT)" \
	TARGET_PRODUCT_VARIANT="$(TARGET_PRODUCT_VARIANT)" \
	TARGET_OS="$(TARGET_OS)" \
	TARGET_OS_FLAVOUR="$(TARGET_OS_FLAVOUR)" \
	TARGET_LIBC="$(TARGET_LIBC)" \
	TARGET_ARCH="$(TARGET_ARCH)" \
	TARGET_CPU="$(TARGET_CPU)"

# Tools
CONFWRAPPER := $(CONFWRAPPER_ENV) $(BUILD_SYSTEM)/scripts/confwrapper.py

# File where global configuration is stored
ifndef CONFIG_GLOBAL_FILE
  CONFIG_GLOBAL_FILE := $(TARGET_CONFIG_DIR)/global.config
endif

# Remember if the global config file is present or not
ifeq ("$(wildcard $(CONFIG_GLOBAL_FILE))","")
  CONFIG_GLOBAL_FILE_AVAILABLE := 0
else
  CONFIG_GLOBAL_FILE_AVAILABLE := 1
endif

# Include global config file, do not fail if it does not exists or we
# are requested to skip checks.
ifeq ("$(CONFIG_GLOBAL_FILE_AVAILABLE)","1")
  ifeq ("$(SKIP_CONFIG_CHECK)","0")
    include $(CONFIG_GLOBAL_FILE)
  else
    -include $(CONFIG_GLOBAL_FILE)
  endif
endif

###############################################################################
## Get the name of the configuration file of a module.
## Priority is:
## - custom config specified in custom.<module>.config if it exists.
## - $(TARGET_CONFIG_DIR)/$1.config if it exists.
## - sdk.$1.config if module is from a sdk.
## - $(TARGET_CONFIG_DIR)/$1.config (even if it does not exist.
##
## $1 : module name.
###############################################################################

# Path to original file given as input
__get-orig-module-config = $(strip \
	$(if $(call is-var-defined,custom.$1.config), \
		$(custom.$1.config) \
		, \
		$(if $(wildcard $(TARGET_CONFIG_DIR)/$1.config), \
			$(TARGET_CONFIG_DIR)/$1.config \
			, \
			$(if $(call is-var-defined,sdk.$1.config), \
				$(sdk.$1.config) \
				, \
				$(TARGET_CONFIG_DIR)/$1.config \
			) \
		) \
	))

# Path to file copied in build (after optional patching with sed files)
__get-build-module-config = $(strip \
	$(call module-get-build-dir,$1)/$1.config)

# Public version will get original file (required by busybox and linux kernel)
module-get-config = $(call __get-orig-module-config,$1)

###############################################################################
## Get the list of path to Config.in files of a module.
## $1 : module name.
## Remark : should be called only after the module database have been built.
###############################################################################
__get-module-config-in-files = $(strip \
	$(eval __path := $(__modules.$1.PATH)) \
	$(eval __files := $(__modules.$1.CONFIG_FILES)) \
	$(addprefix $(__path)/,$(__files)))

###############################################################################
## Generate arguments suitable for an action on a module config.
###############################################################################

# Escape description so it can be inserted as a parameter in the command line
# It removes completely '|' and escape quotes.
# $1 : description
__config-desc-escape = $(subst ",\",$(subst |,$(empty),$1))

# Generate arguments suitable for an action on a module config.
# $1 : module name
__generate-config-module-args = $(strip \
	$(eval __mod := $1) \
	$(eval __desc := $(call __config-desc-escape,$(__modules.$(__mod).DESCRIPTION))) \
	$(eval __depends := $(call module-get-config-depends,$(__mod))) \
	$(eval __dependsCond := $(__modules.$(__mod).CONDITIONAL_LIBRARIES)) \
	$(eval __modPath := $(call path-from-top,$(__modules.$(__mod).PATH))) \
	$(eval __categoryPath := $(__modules.$(__mod).CATEGORY_PATH)) \
	$(eval __sdk := $(__modules.$(__mod).SDK)) \
	$(eval __configInFiles := $(call __get-module-config-in-files,$(__mod))) \
	$(if $(__configInFiles), \
		$(eval __configPath := $(call __get-orig-module-config,$(__mod))), \
		$(eval __configPath := $(empty)) \
	) \
	$(eval __arg := $(__mod)|$(__desc)|$(__depends)|$(__dependsCond)|$(__modPath)) \
	$(eval __arg := $(__arg)|$(__categoryPath)|$(__sdk)|$(__configPath)) \
	$(foreach __f,$(__configInFiles), \
		$(eval __arg := $(__arg)|$(abspath $(__f))) \
	) \
	"$(__arg)")

###############################################################################
## Generate arguments suitable for an action on a full config.
## Do not include prebuilt modules, it has no real sense.
## Autotools modules won't compile under ecos, so don't bother display them or
## any module that has a dependency on it.
## Host module will be activated internally when necessary so don't display them.
###############################################################################

# Check if a module has a dependency on an autotools module
# $1 : module name
__has-autotools-deps = $(strip \
	$(foreach __mod,$(call module-get-all-depends,$1), \
		$(call streq,$(__modules.$(__mod).MODULE_CLASS),AUTOTOOLS) \
	))

# Check if a single module shall be displayed in the config
# $1 : module name
__show-in-config = $(strip \
	$(if $(or $(call is-module-prebuilt,$1),$(call is-module-host,$1)), \
		$(false), \
		$(if $(call strneq,$(TARGET_OS),ecos), \
			$(true), \
			$(if $(call streq,$(__modules.$1.MODULE_CLASS),AUTOTOOLS), \
				$(false), \
				$(if $(call __has-autotools-deps,$1),$(false),$(true)) \
			) \
		) \
	))

# No arguments
__generate-config-args = $(strip \
	$(foreach __mod,$(__modules), \
		$(if $(or $(call __show-in-config,$(__mod)),$(__modules.$(__mod).SDK)), \
			$(call __generate-config-module-args,$(__mod)) \
		) \
	))

###############################################################################
## Load configuration of a module.
## A copy is made in the build directory (with optional sed files applied).
## $1: module name.
###############################################################################

# Path to script used to apply sed files on config file
__apply-sed-script := $(BUILD_SYSTEM)/scripts/config-apply-sedfiles.sh

# Separate sed files application from __load-config-internal
## (optional) different destination file can be passed as second argument.
__config-apply-sed = \
	$(eval __cas_src_file := $(or $3,$(call __get-orig-module-config,$1))) \
	$(eval __cas_dst_file := $(or $2,$(call __get-build-module-config,$1))) \
	$(if $(call is-var-defined,custom.$1.config.sedfiles), \
	$(foreach __f,$(custom.$1.config.sedfiles), \
		$(info Apply $(__f) on '$1' config) \
	) \
	$(eval __out := $(shell $(__apply-sed-script) \
		$(__cas_src_file) \
		$(__cas_dst_file) \
		$(custom.$1.config.sedfiles) \
	)) \
	, \
	$(shell mkdir -p $(dir $(__cas_dst_file))) \
	$(shell cp -af $(__cas_src_file) $(__cas_dst_file)) \
)

define __load-config-internal
$(if $(wildcard $(call __get-orig-module-config,$1)), \
	$(if $(call strneq,$(V),0), \
		$(info $1: Loading config file $(call __get-orig-module-config,$1)) \
	)
	$(call __config-apply-sed,$1) \
	, \
	$(shell mkdir -p $(dir $(call __get-build-module-config,$1))) \
	$(shell [ -e $(call __get-build-module-config,$1) ] || touch $(call __get-build-module-config,$1)) \
)
-include $(call __get-build-module-config,$1)
$(eval __modules.$1.config-loaded := 1)
endef

###############################################################################
## Load configuration of a module.
## Simply evaluate a call to simplify job of caller.
###############################################################################
load-config = $(if $(call is-var-undefined,__modules.$(LOCAL_MODULE).config-loaded), \
	$(eval $(call __load-config-internal,$(LOCAL_MODULE))))
