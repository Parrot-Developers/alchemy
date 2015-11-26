###############################################################################
## @file defs.mk
## @author Y.M. Morgan
## @date 2011/05/14
##
## This file contains macros used by other makefiles.
###############################################################################

###############################################################################
## Some useful macros.
###############################################################################

# Empty variable and space (useful for pretty prinf of messages)
empty :=
space := $(empty) $(empty)
space4 := $(space)$(space)$(space)$(space)

# Other special characters definition (useful to avoid parsing error in functions)
dollar := $$
comma := ,
colon := :
left-paren := (
right-paren := )

# True/False values. Any non-empty test is considered as True
true := T
false :=

# New line definition, please keep the two and only two empty lines in the macro
define endl


endef

# Return negation of argument.
# $1 : input boolean argument.
not = $(if $1,$(false),$(true))

# Return the first element of a list.
# $1 : input list.
first = $(firstword $1)

# Return the list with the first element removed.
# $1 : input list.
rest = $(wordlist 2,$(words $1),$1)

# Get a path relative to top directory.
# $1 : full path to convert.
path-from-top = $(patsubst $(TOP_DIR)/%,%,$1)

# Replace '-' by '_' and convert to upper case.
# $1 : text to convert.
_from := a b c d e f g h i j k l m n o p q r s t u v w x y z . -
_to   := A B C D E F G H I J K L M N O P Q R S T U V W X Y Z _ _
_conv := $(join $(addsuffix :,$(_from)),$(_to))
get-define = $(strip \
	$(eval __gdtmp := $1) \
	$(foreach __gdpair, $(_conv), \
		$(eval __gdpair2 := $(subst :,$(space),$(__gdpair))) \
		$(eval __gdw1 := $(word 1,$(__gdpair2))) \
		$(eval __gdw2 := $(word 2,$(__gdpair2))) \
		$(eval __gdtmp := $(subst $(__gdw1),$(__gdw2),$(__gdtmp))) \
	) \
	$(__gdtmp))

# Remove quotes from string
remove-quotes = $(strip $(subst ",,$1))

# Check that the current directory is the top directory
check-pwd-is-top-dir = \
	$(if $(patsubst $(TOP_DIR)%,%,$(realpath $(shell pwd))), \
		$(error Not at the top directory))

# Determine if a path is absolute.
# It simply checks if the path starts with a '/'
# $1 : path to check.
is-path-absolute = $(strip $(call not,$(patsubst /%,,$1)))

# Determine if a path is a directory. This check does not look in the
# filesystem, it just checks if the path ends with a '/'.
# $1 : path to check.
is-path-dir = $(strip $(call not,$(patsubst %/,,$1)))

# Compare 2 strings for equality.
# $1 : first string.
# $2 : second string.
streq = $(if $(filter-out xx,x$(subst $1,,$2)$(subst $2,,$1)x),$(false),$(true))

# Compare 2 strings for inequality.
# $1 : first string.
# $2 : second string.
strneq = $(call not,$(call streq,$1,$2))

# Check that a version is at least the one given.
# $1 : version.
# $2 : minimum version.
check-version = $(call strneq,0,$(shell expr $1 \>= $2))

# Make sure an item appears only once in a list, keeping only the last reference.
# $1 : input list.
uniq2 = \
	$(eval __r := $1) \
	$(foreach __f,$1, \
		$(eval __r := $(call rest,$(__r))) \
		$(if $(filter $(__f),$(__r)),,$(__f)) \
	)

# Determine if a variable has been defined
# $1 : name of the variable (not its content)
is-var-defined = $(call strneq,$(origin $1),undefined)

# Determine if a variable is not defined
# $1 : name of the variable (not its content)
is-var-undefined = $(call streq,$(origin $1),undefined)

# Dertermine if an item is in a list
# $1 : item to search.
# $2 : list.
is-item-in-list = $(strip $(foreach __it,$2,$(call streq,$(__it),$1)))

# Dertermine if an item is not in a list
# $1 : item to search.
# $2 : list.
is-not-item-in-list = $(call not,$(call is-item-in-list,$1,$2))

# Determine if a string starts with a given prefix
# $1 : input string
# $2 : prefix to check
str-starts-with = $(strip $(call not,$(patsubst $2%,,$1)))

# Determine if a string ends with a given suffix
# $1 : input string
# $2 : suffix to check
str-ends-with = $(strip $(call not,$(patsubst %$2,,$1)))

# Remove trailing '/' from a path
# $1 : input string
remove-trailing-slash = $(strip $(patsubst %/,%,$1))

###############################################################################
## Use some colors if requested.
###############################################################################

# Using $'string' format to allow color escaping compatible with mac and linux
# Double $ is for make interpretation
ifeq ("$(USE_COLORS)","1")
  CLR_DEFAULT := $(shell echo $$'\033[00m')
  CLR_RED     := $(shell echo $$'\033[31m')
  CLR_GREEN   := $(shell echo $$'\033[32m')
  CLR_YELLOW  := $(shell echo $$'\033[33m')
  CLR_BLUE    := $(shell echo $$'\033[34m')
  CLR_PURPLE  := $(shell echo $$'\033[35m')
  CLR_CYAN    := $(shell echo $$'\033[36m')
else
  CLR_DEFAULT :=
  CLR_RED     :=
  CLR_GREEN   :=
  CLR_YELLOW  :=
  CLR_BLUE    :=
  CLR_PURPLE  :=
  CLR_CYAN    :=
endif

###############################################################################
## Modules database.
## For each module 'mod', __modules.mod.<field> is used to store
## module-specific information.
###############################################################################
__modules := $(empty)

###############################################################################
## Custom macros database.
## Contains a list of macros that can be used in LOCAL_CUSTOM_MACROS by module.
## A module can register a global custom macros with local-register-custom-macro.
###############################################################################
__custom-macros := $(empty)

###############################################################################
## Clear a list of variables.
###############################################################################
clear-vars = $(foreach __varname,$1,$(eval $(__varname) := $(empty)))

###############################################################################
## The list of fields related to dependency
###############################################################################
modules-fields-depends := \
	depends \
	depends.EXTERNAL_LIBRARIES \
	depends.STATIC_LIBRARIES \
	depends.WHOLE_STATIC_LIBRARIES \
	depends.SHARED_LIBRARIES \
	depends.link \
	depends.other \
	depends.headers \
	depends.all

###############################################################################
## Add a module in the build system and save its LOCAL_xxx variables.
## All LOCAL_xxx variables will be saved in module database.
## An internal prebuilt module (for example a bionic one) will take precedence
## over another module with the same name.
## A module comming from a sdk will be overidden by a standard module.
## A host module (LOCAL_HOST_MODULE set) will have its internal name
## prefixed by 'host.'.
###############################################################################
module-add = \
	$(eval LOCAL_MODULE := $(strip $(LOCAL_MODULE))) \
	$(if $(LOCAL_MODULE),$(empty), \
		$(error $(LOCAL_PATH): LOCAL_MODULE is not defined)) \
	$(if $(call not,$(patsubst host.%,,$(LOCAL_MODULE))), \
		$(error $(LOCAL_PATH): Do NOT use 'host.' prefix, use LOCAL_HOST_MODULE) \
	) \
	$(if $(LOCAL_HOST_MODULE), \
		$(if $(or $(call streq,$(LOCAL_MODULE_CLASS),AUTOTOOLS), \
				$(call streq,$(LOCAL_MODULE_CLASS),CUSTOM), \
				$(call streq,$(LOCAL_MODULE_CLASS),PREBUILT)), \
			$(eval LOCAL_MODULE := host.$(LOCAL_MODULE)), \
			$(error $(LOCAL_PATH): Only AUTOTOOLS/CUSTOM/PREBUILT supported for host modules) \
		) \
	) \
	$(eval __mod := $(LOCAL_MODULE)) \
	$(eval __add := 1) \
	$(if $(__clear-vars-called),$(empty), \
		$(error $(LOCAL_PATH): $(__mod): missing include $$(CLEAR_VARS)) \
	) \
	$(if $(call is-module-registered,$(__mod)), \
		$(if $(__modules.$(__mod).SDK), \
			$(if $(patsubst $(BUILD_SYSTEM)/%,,$(LOCAL_PATH)), \
				$(info $(LOCAL_PATH): module '$(__mod)' overwrites sdk at $(__modules.$(__mod).SDK)) \
				$(foreach __local,$(vars-LOCAL), \
					$(eval __modules.$(__mod).$(__local) := $(empty))) \
				$(foreach __local,$(macros-LOCAL), \
					$(eval __modules.$(__mod).$(__local) := $(empty))) \
				, \
				$(eval __add := 0) \
			) \
			, \
			$(eval __add := 0) \
			$(eval __path := $(__modules.$(__mod).PATH)) \
			$(eval __class := $(__modules.$(__mod).MODULE_CLASS)) \
			$(if $(call streq,$(__class),PREBUILT), \
				$(info $(LOCAL_PATH): module '$(__mod)' is already prebuilt), \
				$(error $(LOCAL_PATH): module '$(__mod)' already registered at $(__path)) \
			) \
		) \
	) \
	$(if $(call streq,$(__add),1), \
		$(eval __modules += $(__mod)) \
		$(foreach __local,$(vars-LOCAL), \
			$(eval __modules.$(__mod).$(__local) := $(LOCAL_$(__local))) \
		) \
		$(foreach __local,$(macros-LOCAL), \
			$(call macro-copy,__modules.$(__mod).$(__local),LOCAL_$(__local)) \
		) \
		$(if $(or $(call streq,$(LOCAL_MODULE_CLASS),CUSTOM), \
				$(call streq,$(LOCAL_MODULE_CLASS),META_PACKAGE)), \
			$(if $(LOCAL_MODULE_FILENAME), \
				$(eval __modules.$(__mod).check-done-file-created := $(true)) \
				, \
				$(eval __modules.$(__mod).check-done-file-created := $(false)) \
				$(eval __modules.$(__mod).MODULE_FILENAME := $(__mod).done) \
			) \
		) \
		$(call install-headers-setup,$(LOCAL_MODULE)) \
	) \
	$(eval __var := GLOBAL_PREREQUISITES) \
	$(if $(call macro-compare,TARGET_$(__var),saved-TARGET_$(__var)),$(empty), \
		$(eval __modules-with-global-prerequisites += $(__mod)) \
		$(call macro-copy,saved-TARGET_$(__var),TARGET_$(__var)) \
	) \
	$(eval __clear-vars-called :=)

###############################################################################
## Get the module name as a 'define' value to be used in kconfig and CFLAGS.
## $1 : module name.
###############################################################################
module-get-define = $(strip \
	$(if $(call is-var-undefined,__modules.$1.define), \
		$(eval __modules.$1.define := $(call get-define,$1)) \
	) \
	$(__modules.$1.define))

###############################################################################
## Check if a list of targets is given in make goals.
## $1 : list of targets to check
###############################################################################
is-targets-in-make-goals = $(strip \
	$(foreach __t,$1, \
		$(foreach __g,$(MAKECMDGOALS), \
			$(call streq,$(__g),$(__t)) \
		) \
	))

###############################################################################
## Check if a module is given in make goals
## It consider its clean/dirclean as well.
## $1 : module to check.
###############################################################################
is-module-in-make-goals = $(strip \
	$(call is-targets-in-make-goals,$1 $1-clean $1-dirclean $1-path $1-codecheck $1-cloc $1-doc $1-cppcheck))

###############################################################################
## Check if a module is registered. It simply verifies that the variable
## __modules.$1.PATH has been set.
## $1 : module to check.
###############################################################################
is-module-registered = $(call is-var-defined,__modules.$1.PATH)

###############################################################################
## Check if a module is built externally (by autotools or custom rules).
## $1 : module to check.
## AUTOTOOLS/CMAKE/QMAKE/PYTHON_EXTENSION/GENERIC/CUSTOM/META_PACKAGE class or empty
## class means external.
###############################################################################
is-module-external = $(strip \
	$(eval __class := $(__modules.$1.MODULE_CLASS)) \
	$(or $(call streq,$(__class),AUTOTOOLS), \
		$(call streq,$(__class),CMAKE), \
		$(call streq,$(__class),QMAKE), \
		$(call streq,$(__class),PYTHON_EXTENSION), \
		$(call streq,$(__class),GENERIC), \
		$(call streq,$(__class),CUSTOM) \
		$(call streq,$(__class),META_PACKAGE) \
	))

###############################################################################
## Check if a module is prebuilt.
## $1 : module to check.
## Note : a module is prebuilt if its class is PREBUILT or is part of a sdk
## in which case LOCAL_SDK is not empty
###############################################################################
is-module-prebuilt = $(strip \
	$(or \
		$(call streq,$(__modules.$1.MODULE_CLASS),PREBUILT), \
		$(__modules.$1.SDK) \
	))

###############################################################################
## Check if a module is a meta package.
## $1 : module to check.
###############################################################################
is-module-meta-package = $(call streq,$(__modules.$1.MODULE_CLASS),META_PACKAGE)

###############################################################################
## Check if a module is for the host.
## $1 : module to check.
## A module is for the host if the name starts with 'host.'
###############################################################################
is-module-host = $(strip $(call not,$(patsubst host.%,,$1)))

###############################################################################
## Normalize a host module by removing the 'host.' prefix.
## $1 : host module to normalize.
###############################################################################
module-normalize-host = $(patsubst host.%,%,$1)

###############################################################################
## Get the list of required host modules by the input list of modules.
## $1 : list of modules (it may contains host modules that will be ignored).
## It first creates a list of all directly needed host modules, then expands
## with dependencies of those modules.
###############################################################################
modules-get-required-host = $(strip $(sort \
	$(foreach __mod,$(call __modules-get-required-host-direct,$1), \
		$(__mod) $(__modules.$(__mod).depends.all) \
	)))

# Get direct required list
__modules-get-required-host-direct = $(strip $(sort \
	$(foreach __mod,$1,$(__modules.$(__mod).DEPENDS_HOST_MODULES))))

###############################################################################
## Check if a module will be built.
## $1 : module to check.
## Prebuild modules are considered as in the config (even if they are
## not actually in it).
## If no global configuration file present, always return true (unless if was
## forcibly disabled).
###############################################################################
is-module-in-build-config = $(strip \
	$(if $(call is-module-registered,$1), \
		$(if $(call is-module-prebuilt,$1), \
			$(true) \
			, \
			$(if $(call streq,$(CONFIG_GLOBAL_FILE_AVAILABLE),1), \
				$(eval __var := CONFIG_ALCHEMY_BUILD_$(call module-get-define,$1)) \
				$(if $(call is-var-defined,$(__var)), \
					$(if $($(__var)),$(true),$(false)) \
					, \
					$(false) \
				) \
				, \
				$(call not,$(call is-var-defined,__modules.$(__mod).force-disabled)) \
			) \
		) \
	))

###############################################################################
## Force disabling a module when there is no global configuration file.
## $1 : module name
###############################################################################
module-force-disabled = \
	$(eval __modules.$1.force-disabled := 1)

###############################################################################
## Restore the recorded LOCAL_XXX definitions for a given module. Called
## for each module once they have all been registered and their dependencies
## have been computed to actually define rules.
## $1 : name of module to restore.
###############################################################################
module-restore-locals = \
	$(foreach __local,$(vars-LOCAL), \
		$(eval LOCAL_$(__local) := $(__modules.$1.$(__local))) \
	) \
	$(foreach __local,$(macros-LOCAL), \
		$(call macro-copy,LOCAL_$(__local),__modules.$1.$(__local)) \
	)

###############################################################################
## Used to check all dependencies once all module information has been
## recorded.
###############################################################################

# Check dependencies of all modules. Only if module will be built and not from
# a sdk.
modules-check-depends = \
	$(foreach __mod,$(__modules), \
		$(if $(call is-module-in-build-config,$(__mod)), \
			$(if $(__modules.$(__mod).SDK),$(empty), \
				$(call __module-check-depends,$(__mod)) \
			) \
		) \
	)

# Check dependencies of a module.
# $1 : module name.
__module-check-depends = \
	$(eval __path := $(__modules.$1.PATH)) \
	$(call __module-check-depends-direct,$1) \
	$(call __module-check-depends-other,$1) \
	$(call __module-check-depends-headers,$1) \
	$(call __module-check-depends-mode,$1) \
	$(call __module-check-libs-class,$1,WHOLE_STATIC_LIBRARIES,STATIC_LIBRARY) \
	$(call __module-check-libs-class,$1,STATIC_LIBRARIES,STATIC_LIBRARY) \
	$(call __module-check-libs-class,$1,SHARED_LIBRARIES,SHARED_LIBRARY)

# Check direct dependencies
# $1 : module name.
__module-check-depends-direct = \
	$(foreach __lib,$(__modules.$1.depends), \
		$(if $(call is-module-registered,$(__lib)), \
			$(if $(call is-module-in-build-config,$(__lib)),$(empty), \
				$(if $(call is-var-defined,TARGET_TEST),$(empty), \
					$(error $(__path): module '$1' depends on disabled module '$(__lib)') \
				) \
			), \
			$(error $(__path): module '$1' depends on unknown module '$(__lib)') \
		) \
	)

# Make sure runtime dependencies (other) are OK. Print warning only
# $1 : module name.
__module-check-depends-other = \
	$(foreach __lib,$(__modules.$1.depends.other), \
		$(if $(call is-module-registered,$(__lib)), \
			$(if $(call is-module-in-build-config,$(__lib)),$(empty), \
				$(warning $(__path): module '$1' requires disabled module '$(__lib)') \
			), \
			$(warning $(__path): module '$1' requires unknown module '$(__lib)') \
		) \
	)

# Make sure headers dependencies are OK.
# $1 : module name.
__module-check-depends-headers = \
	$(foreach __lib,$(__modules.$1.depends.headers), \
		$(if $(call is-module-registered,$(__lib)),$(empty), \
			$(error $(__path): module '$1' depends on headers of unknown module '$(__lib)') \
		) \
	)

# $1 : module name of owner.
# $2 : dependency to check (WHOLE_STATIC_LIBRARIES,STATIC_LIBRARIES,SHARED_LIBRARIES).
# $3 : class to check (STATIC_LIBRARY,SHARED_LIBRARY)
__module-check-libs-class = \
	$(foreach __lib,$(__modules.$1.$2), \
		$(call __module-check-lib-class,$1,$(__lib),$3) \
	)

# Check that a dependency is of the correct class
# $1 : module name of owner.
# $2 : library to check.
# $3 : class to check (STATIC_LIBRARY,SHARED_LIBRARY)
__module-check-lib-class = \
	$(eval __class := $(__modules.$2.MODULE_CLASS)) \
	$(if $(and $(call strneq,$(__class),$3),$(call strneq,$(__class),LIBRARY)), \
		$(eval __path := $(__modules.$1.PATH)) \
		$(error $(__path): module '$1' depends on module '$2' which is not of class '$3') \
	)

# Check coherence between host/target modules
# $1 : module name.
__module-check-depends-mode = \
	$(if $(call is-module-host,$1), \
		$(call __module-check-depends-host,$1), \
		$(call __module-check-depends-target,$1) \
	) \
	$(foreach __lib,$(__modules.$1.DEPENDS_HOST_MODULES), \
		$(if $(call is-module-host,$(__lib)),$(empty), \
			$(error $(__path): module '$1': LOCAL_DEPENDS_HOST_MODULES contains non host module '$(__lib)') \
		) \
	)

# Check that a host module only depends on host modules
__module-check-depends-host = \
	$(eval __path := $(__modules.$1.PATH)) \
	$(foreach __lib,$(__modules.$1.depends.all), \
		$(if $(call is-module-host,$(__lib)),$(empty), \
			$(error $(__path): host module '$1' depends on non host module '$(__lib)') \
		) \
	)

# Check that a target module only depends on target modules
__module-check-depends-target = \
	$(eval __path := $(__modules.$1.PATH)) \
	$(foreach __lib,$(__modules.$1.depends.all), \
		$(if $(call is-module-host,$(__lib)), \
			$(error $(__path): module '$1' depends on host module '$(__lib)') \
		) \
	) \

###############################################################################
## Used to make some internal checks.
###############################################################################

# Check variables of all modules. Only if module will be built
modules-check-variables = \
	$(foreach __mod,$(__modules), \
		$(if $(call is-module-in-build-config,$(__mod)), \
			$(call __module-check-variables,$(__mod)) \
		) \
	)

# Check variables of a module
# $1 : module name.
__module-check-variables = \
	$(call __module-check-src-files,$1) \
	$(call __module-check-c-includes,$1,$(__modules.$1.C_INCLUDES),uses) \
	$(call __module-check-c-includes,$1,$(__modules.$1.EXPORT_C_INCLUDES),exports) \

# Check that all files listed in LOCAL_SRC_FILES exist
# $1 : module name.
__module-check-src-files = \
	$(eval __path := $(__modules.$1.PATH)) \
	$(foreach __file,$(__modules.$1.SRC_FILES), \
		$(if $(wildcard $(__path)/$(__file)),$(empty), \
			$(warning $(__path): module '$1' uses missing source file '$(__file)') \
		) \
	)

# Check that all directory listed in LOCAL_C_INCLUDES exist. Only check the
# ones relative to LOCAL_PATH (others may not exist yet if in build/staging)
# $1 : module name.
# $2 : list of include directory to check.
# $3 : message : 'uses' or 'exports'
__module-check-c-includes = \
	$(eval __path := $(__modules.$1.PATH)) \
	$(foreach __inc,$(patsubst -I%,%,$2), \
		$(if $(call not,$(patsubst $(__path)%,,$(__inc))), \
			$(if $(wildcard $(__inc)),$(empty), \
				$(warning $(__path): module '$1' $3 missing include '$(__inc)') \
			) \
		) \
	)

###############################################################################
## Enable automatically all dependencies when under TARGET_TEST
###############################################################################

# Enable dependencies of enabled modules or modules given in goals
modules-enable-test-depends = \
	$(foreach __mod,$(__modules), \
		$(if $(or $(call is-module-in-make-goals,$(__mod)), \
				$(call is-module-in-build-config,$(__mod))), \
			$(call __module-enable-test-depends,$(__mod)), \
		) \
	)

# Enable dependencies of a module, this is recursive. As loop should have been
# checked already, it is safe
# $1 : module name
__module-enable-test-depends = \
	$(foreach __lib,$(__modules.$1.depends), \
		$(if $(call is-module-in-build-config,$(__lib)),$(empty), \
			$(info module '$1' forces activation of module '$(__lib)' under test) \
			$(eval CONFIG_ALCHEMY_BUILD_$(call module-get-define,$(__lib)) := y) \
			$(call __module-enable-test-depends,$(__lib)) \
		) \
	)

###############################################################################
## Used to compute all dependencies once all module information has been
## recorded.
###############################################################################

# Variable used to detect cycles in recursion. It will hold all modules
# processed so far. If a module is already in the list, a loop is detected
__depends-loop :=

# Determine if a module is already in the recursion
# $1 : module to check
__is-in-depends-loop = $(strip \
	$(foreach __i,$(__depends-loop), \
		$(call streq,$1,$(__i)) \
	))

# Compute dependencies of all modules
# Do direct dependencies first, then full
# The dummy assignment is to discard output generated internally
modules-compute-depends = \
	$(foreach __mod,$(__modules), \
		$(call conditional-libraries-setup,$(__mod)) \
		$(foreach __field,$(modules-fields-depends), \
			$(eval __modules.$(__mod).$(__field) := $(empty)) \
		) \
		$(call __module-update-depends-direct,$(__mod)) \
		$(call __module-compute-depends-direct,$(__mod)) \
	) \
	$(foreach __mod,$(__modules), \
		$(eval __depends-loop := $(empty)) \
		$(eval __dummy := $(call __module-compute-depends-static,$(__mod),EXTERNAL_LIBRARIES)) \
		$(eval __depends-loop := $(empty)) \
		$(eval __dummy := $(call __module-compute-depends-static,$(__mod),STATIC_LIBRARIES)) \
		$(eval __depends-loop := $(empty)) \
		$(eval __dummy := $(call __module-compute-depends-static,$(__mod),WHOLE_STATIC_LIBRARIES)) \
		$(eval __depends-loop := $(empty)) \
		$(eval __dummy := $(call __module-compute-depends-static,$(__mod),SHARED_LIBRARIES)) \
		$(eval __depends-loop := $(empty)) \
		$(eval __dummy := $(call __module-compute-depends-all,$(__mod))) \
		$(if $(call streq,$(__modules.$(__mod).MODULE_CLASS),EXECUTABLE), \
			$(if $(findstring -static,$(__modules.$(__mod).LDFLAGS)), \
				$(call __module-update-static-executable,$(__mod)) \
			) \
		) \
		$(call __module-compute-depends-link,$(__mod)) \
	)

# Update direct dependencies of a single module.
# It updates XXX_LIBRARIES based on LIBRARIES and actual dependency class.
# $1 : module name.
__module-update-depends-direct = \
	$(foreach __lib,$(__modules.$1.LIBRARIES), \
		$(if $(call is-module-registered,$(__lib)), \
			$(eval __class := $(__modules.$(__lib).MODULE_CLASS)) \
			, \
			$(eval __class := $(empty)) \
		) \
		$(if $(call streq,$(__class),STATIC_LIBRARY), \
			$(if $(call streq,$(__modules.$(__lib).FORCE_WHOLE_STATIC_LIBRARY),1), \
				$(eval __modules.$1.WHOLE_STATIC_LIBRARIES += $(__lib)), \
				$(eval __modules.$1.STATIC_LIBRARIES += $(__lib)) \
			) \
		, \
			$(if $(call streq,$(__class),SHARED_LIBRARY), \
				$(eval __modules.$1.SHARED_LIBRARIES += $(__lib)) \
			, \
				$(if $(call streq,$(__class),LIBRARY), \
					$(eval __modules.$1.SHARED_LIBRARIES += $(__lib)) \
					, \
					$(eval __modules.$1.EXTERNAL_LIBRARIES += $(__lib)) \
				) \
			) \
		) \
	)

# Compute direct dependencies of a single module
# $1 : module name.
__module-compute-depends-direct = \
	$(call __module-add-depends-direct,$1,$(__modules.$1.STATIC_LIBRARIES)) \
	$(call __module-add-depends-direct,$1,$(__modules.$1.WHOLE_STATIC_LIBRARIES)) \
	$(call __module-add-depends-direct,$1,$(__modules.$1.SHARED_LIBRARIES)) \
	$(call __module-add-depends-direct,$1,$(__modules.$1.EXTERNAL_LIBRARIES)) \
	$(eval __modules.$1.depends.headers := $(__modules.$1.DEPENDS_HEADERS)) \
	$(eval __modules.$1.depends.other := $(__modules.$1.DEPENDS_MODULES)) \
	$(eval __modules.$1.depends.other += $(__modules.$1.REQUIRED_MODULES))

# Add direct dependencies to a module
# $1 : module name.
# $2 : list of modules to add in dependency list.
__module-add-depends-direct = \
	$(eval __modules.$1.depends += $(filter-out $(__modules.$1.depends),$2))

# Compute dependencies due to static libraries.
# $1 : module name.
# $2 : class of library to compute dependencies.
# Note : it recursively descends into static libraries to get their dependencies.
# Internally we use a 'local' variable that will hold the name of the variable
# in which we will store the result (a kind of pointer)
# It is prefixed by the name of the module because there is no 'stack' but a
# single namespace.
# Note : the result is ordered in way compatible to link. It means that if
# a library A depends on library B, B will be after A. This order is guaranteed
# even if the recursion and dependency is tricky as long as there is no cycle.
__module-compute-depends-static = \
	$(if $(call __is-in-depends-loop,$1), \
		$(error cyclic dependency detected: $(__depends-loop) $1) \
	) \
	$(eval __depends-loop += $1) \
	$(eval $1.__var := __modules.$1.depends.$2) \
	$(if $($($1.__var)),$($($1.__var)), \
		$(eval $($1.__var) := $(strip \
			$(call uniq2,$(call __module-compute-depends-static-internal,$1,$2))) \
		) \
		$($($1.__var)) \
	) \
	$(eval __depends-loop := $(filter-out $1,$(__depends-loop)))

# Internal macro called by __module-compute-depends-static to do the recursion
# by calling again __module-compute-depends-static.
# $1 : module name.
# $2 : class of library to compute dependencies.
__module-compute-depends-static-internal = \
	$(__modules.$1.$2) \
	$(foreach __mod,$(__modules.$1.STATIC_LIBRARIES), \
		$(if $(call is-module-registered,$(__mod)), \
			$(call __module-compute-depends-static,$(__mod),$2) \
		) \
	) \
	$(foreach __mod,$(__modules.$1.WHOLE_STATIC_LIBRARIES), \
		$(if $(call is-module-registered,$(__mod)), \
			$(call __module-compute-depends-static,$(__mod),$2) \
		) \
	)

# When forcing static libraries, take into account external libraries as well
# Otherwise assume they are mostly shared libraries
ifeq ("$(TARGET_FORCE_STATIC)","1")
__module-compute-depends-static-internal += \
	$(foreach __mod,$(__modules.$1.EXTERNAL_LIBRARIES), \
		$(if $(call is-module-registered,$(__mod)), \
			$(call __module-compute-depends-static,$(__mod),$2) \
		) \
	)
endif

# Compute dependencies for link. It simply aggregate (and sort) dependencies
# $1 : module name.
__module-compute-depends-link = \
	$(eval __modules.$1.depends.link := $(strip $(sort \
		$(__modules.$1.depends.EXTERNAL_LIBRARIES) \
		$(__modules.$1.depends.STATIC_LIBRARIES) \
		$(__modules.$1.depends.WHOLE_STATIC_LIBRARIES) \
		$(__modules.$1.depends.SHARED_LIBRARIES) \
	)))

# Compute all dependencies of a module.
# $1 : module name.
# Note : it recursively descends into modules to get their dependencies.
# See above the way we use 'local' variable.
# Order is kept compatible with a static link.
__module-compute-depends-all = \
	$(if $(call __is-in-depends-loop,$1), \
		$(error cyclic dependency detected: $(__depends-loop) $1) \
	) \
	$(eval __depends-loop += $1) \
	$(eval $1.__var := __modules.$1.depends.all) \
	$(if $($($1.__var)),$($($1.__var)), \
		$(eval $($1.__var) := $(strip \
			$(call uniq2,$(call __module-compute-depends-all-internal,$1))) \
		) \
		$($($1.__var)) \
	) \
	$(eval __depends-loop := $(filter-out $1,$(__depends-loop)))

# Internal macro called by __module-compute-depends-all to do the recursion
# by calling again __module-compute-depends-all.
# $1 : module name.
__module-compute-depends-all-internal = \
	$(__modules.$1.depends) \
	$(foreach __mod,$(__modules.$1.depends), \
		$(if $(call is-module-registered,$(__mod)), \
			$(call __module-compute-depends-all,$(__mod)) \
		) \
	)

# Update dependencies for static executables.
# $1 : module name.
# Note : for each generic library in depends.all, it will transform shared
# version to static version.
__module-update-static-executable = \
	$(foreach __lib,$(__modules.$1.depends.all), \
		$(if $(call is-module-registered,$(__lib)), \
			$(if $(call streq,$(__modules.$(__lib).MODULE_CLASS),LIBRARY), \
				$(eval __modules.$1.depends.STATIC_LIBRARIES := $(strip \
					$(call uniq2,$(__modules.$1.depends.STATIC_LIBRARIES) $(__lib))) \
				) \
				$(eval __modules.$1.depends.SHARED_LIBRARIES := $(strip \
					$(filter-out $(__lib),$(__modules.$1.depends.SHARED_LIBRARIES))) \
				) \
			) \
		) \
	)

###############################################################################
## Automatic extraction from dependencies of a module.
###############################################################################

# Return the recorded value of LOCAL_EXPORT_$2, if any, for module $1.
# $1 : module name.
# $2 : export variable name without LOCAL_EXPORT_ prefix (e.g. 'CFLAGS').
module-get-export = $(__modules.$1.EXPORT_$2)

# Return the recorded value of LOCAL_EXPORT_$2, if any, for modules listed in $1.
# $1 : list of module names.
# $2 : export variable name without LOCAL_EXPORT_ prefix (e.g. 'CFLAGS').
module-get-listed-export = $(strip \
	$(foreach __mod,$1, \
		$(call module-get-export,$(__mod),$2) \
	))

# Return the autoconf.h file, if any, for module $1.
# $1 : module name.
module-get-autoconf = $(strip \
	$(if $(__modules.$1.CONFIG_FILES), \
		$(if $(call is-module-host,$1), \
			$(HOST_OUT_BUILD)/$(call module-normalize-host,$1)/autoconf-$(call module-normalize-host,$1).h \
			, \
			$(TARGET_OUT_BUILD)/$1/autoconf-$1.h \
		) \
	))

# Return the autoconf.h files, if any, for modules listed in $1.
# $1 : list of module names.
module-get-listed-autoconf = $(strip \
	$(foreach __mod,$1, \
		$(call module-get-autoconf,$(__mod)) \
	))

###############################################################################
## Dependency helpers.
## $1: module name.
###############################################################################

# Get dependencies due to static libraries
module-get-static-depends = \
	$(__modules.$1.depends.$2)

# Get link dependencies for the build (aggregation of all static depends)
# list is sorted and is mainly used for generation of elf section with dependencies.
module-get-link-depends = \
	$(__modules.$1.depends.link)

# Get all dependencies for the build
module-get-all-depends = \
	$(__modules.$1.depends.all)

# Get direct dependencies
module-get-depends = \
	$(__modules.$1.depends)

# Get dependencies for configuration
module-get-config-depends = \
	$(__modules.$1.depends) \
	$(__modules.$1.depends.other)

###############################################################################
## Get path of module main target file (in build or staging directory).
## $1 : module name.
###############################################################################

# Get build directory of a module
# It handle host/target modules
module-get-build-dir = $(strip \
	$(if $(call is-module-host,$1), \
		$(call module-get-build-dir-host,$(call module-normalize-host,$1)) \
		, \
		$(TARGET_OUT_BUILD)/$1 \
	))

# Get build directory of a host module
# $1 : nomalized host moduel (without 'host.' prefix)
module-get-build-dir-host = $(strip $(HOST_OUT_BUILD)/$1)

# Get build file name of a module
# It handle host/target modules
module-get-build-filename = $(strip \
	$(if $(call is-module-host,$1), \
		$(HOST_OUT_BUILD)/$(call module-normalize-host,$1)/$(__modules.$1.MODULE_FILENAME) \
		, \
		$(TARGET_OUT_BUILD)/$1/$(__modules.$1.MODULE_FILENAME) \
	))

# Get staging file name of a module.
# It handle host/target modules as well as SDK modules.
module-get-staging-filename = $(strip \
	$(if $(call is-module-host,$1), \
		$(if $(__modules.$1.SDK), \
			$(__modules.$1.SDK)/host/$(__modules.$1.DESTDIR)/$(__modules.$1.MODULE_FILENAME), \
			$(HOST_OUT_STAGING)/$(__modules.$1.DESTDIR)/$(__modules.$1.MODULE_FILENAME) \
		), \
		$(if $(__modules.$1.SDK), \
			$(__modules.$1.SDK)/$(__modules.$1.DESTDIR)/$(__modules.$1.MODULE_FILENAME), \
			$(TARGET_OUT_STAGING)/$(__modules.$1.DESTDIR)/$(__modules.$1.MODULE_FILENAME) \
		) \
	))

###############################################################################
## Debug cutomization access.
## $1 : module name.
## $2 : field name (CFLAGS, CXXFLAGS, LDFLAGS).
###############################################################################
module-get-debug-flags = $(strip \
	$(if $(call is-var-defined,debug.$1.$2), \
		$(debug.$1.$2) \
	))

###############################################################################
## Module revision management. Assume git is used and return SHA1 of HEAD.
###############################################################################

ifneq ("$(USE_GIT_REV)","0")

# Cache of already compute revisions
__git-rev-cache := $(empty)

# Compute revision of a directory and update cache with the top level directory
# ofthe gir repo containing the given directory.
# Do not add in cache if top level has a .gitmodules
# $1 : path inside of a git repo
__git-rev-compute = \
	$(eval __data := $(shell cd $1 && git rev-parse --show-toplevel HEAD 2>/dev/null)) \
	$(eval __top-level := $(word 1,$(__data))) \
	$(eval __sha1 := $(word 2,$(__data))) \
	$(if $(__top-level), \
		$(eval __desc := $(shell cd $(__top-level) && git describe --tags --always 2>/dev/null)) \
		$(if $(wildcard $(__top-level)/.gitmodules),$(empty), \
			$(eval __git-rev-cache.$(__top-level).sha1 := $(__sha1)) \
			$(eval __git-rev-cache.$(__top-level).desc := $(__desc)) \
			$(eval __git-rev-cache += $(__top-level)) \
		) \
		, \
		$(eval __sha1 := $(empty)) \
		$(eval __desc := $(empty)) \
	)

# Search in cache if directory has already on of its parent in the cache
# If yes, retreive __sha1 and __desc.
# If no, update the cache and retreive __sha1 and __desc.
# $1 : path inside a git repo
__git-rev-get = \
	$(eval __found := $(false)) \
	$(foreach __top-level,$(__git-rev-cache), \
		$(if $(__found),$(empty), \
			$(if $(or $(call streq,$(__top-level),$1), \
					$(call not,$(patsubst $(__top-level)/%,,$1/))), \
				$(eval __sha1 := $(__git-rev-cache.$(__top-level).sha1)) \
				$(eval __desc := $(__git-rev-cache.$(__top-level).desc)) \
				$(eval __found := $(true)) \
			) \
		) \
	) \
	$(if $(__found),$(empty),$(call __git-rev-compute,$1))

# Compute revision of all modules
module-compute-revisions = \
	$(foreach __mod,$(__modules), \
		$(call module-compute-revision,$(__mod)) \
	)

# Compute revision of a single module
# $1: module name
module-compute-revision = \
	$(if $(__modules.$1.REVISION),$(empty), \
		$(eval __path := $(__modules.$1.PATH)) \
		$(call __git-rev-get,$(__path)) \
		$(if $(__sha1),$(empty),$(eval __sha1 := unknown)) \
		$(if $(__desc),$(empty),$(eval __desc := unknown)) \
		$(eval __modules.$1.REVISION := $(__sha1)) \
		$(eval __modules.$1.REVISION_DESCRIBE := $(__desc)) \
		$(if $(call strneq,$(V),0),$(info Revision of $1: $(__sha1) / $(__desc))) \
	) \

# Get revision of one module
# $1 : module name.
module-get-revision = $(strip $(module-compute-revision)$(__modules.$1.REVISION))

# Get revision (with git describe) of one module
# $1 : module name.
module-get-revision-describe = $(strip $(module-compute-revision)$(__modules.$1.REVISION_DESCRIBE))

# Get last revision of one module. It is found in a generated file that may
# not exist so the result can be empty.
# $1 : module name.
module-get-last-revision = $(strip \
	$(if $(call is-var-defined,build.$1.revision.last), \
		$(build.$1.revision.last) \
	))

# Check if revision of module has changed since last build.
# If either current/last revision is unknown, it will return false.
# $1 : module name.
module-check-revision-changed = $(strip \
	$(eval __current := $(call module-get-revision,$1)) \
	$(eval __last := $(call module-get-last-revision,$1)) \
	$(and $(__current),$(__last),$(call strneq,$(__current),$(__last))))

# Generate the file with last revision. Some duplication with
# 'module-check-revision-changed' to update the file only when needed.
# $1 : module name.
# $2 : output file.
# Note: shall be call as a command inside a rule.
generate-last-revision-file = \
	$(eval __current := $(call module-get-revision,$1)) \
	$(eval __last := $(call module-get-last-revision,$1)) \
	$(if $(and $(__current),$(call strneq,$(__current),$(__last))), \
		mkdir -p $(dir $2); \
		echo "build.$1.revision.last=$(__current)" > $2; \
	) \

endif

###############################################################################
## Generate autoconf.h file from config file.
## $1 : input config file.
## $2 : output autoconf.h file.
##
## Remove CONFIG_ prefix.
## Remove CONFIG_ in commented lines.
## Put lines begining with '#' between '/*' '*/'.
## Replace 'key=value' by '#define key value'.
## Replace trailing ' y' by ' 1'.
## Remove leading and trailing quotes from string.
## Replace '\"' by '"'.
###############################################################################
define generate-autoconf-file
	echo "Generating $(call path-from-top,$2) from $(call path-from-top,$1)"; \
	mkdir -p $(dir $2); \
	sed \
		-e 's/^CONFIG_//' \
		-e 's/^\# CONFIG_/\# /' \
		-e 's/^\#\(.*\)/\/*\1 *\//' \
		-e 's/\(.*\)=\(.*\)/\#define \1 \2/' \
		-e 's/ y$$/ 1/' \
		-e 's/\"\(.*\)\"/\1/' \
		-e 's/\\\"/\"/g' \
		$1 > $2;
endef

###############################################################################
## Search files matching an extension under LOCAL_PATH.
###############################################################################

# $1 : directory relative to LOCAL_PATH to search
# $2 : extension to search (.c, .cpp ...)
all-files-under = $(strip \
	$(patsubst ./%,%, \
		$(shell cd $(LOCAL_PATH); \
			find $1 -name "*$2" -and -not -name ".*") \
	))

# $1 : directory relative to LOCAL_PATH to search
all-c-files-under = $(call all-files-under,$1,.c)
all-cpp-files-under = $(call all-files-under,$1,.cpp)
all-cxx-files-under = $(call all-files-under,$1,.cxx)
all-cc-files-under = $(call all-files-under,$1,.cc)

###############################################################################
## Search files matching an extension under LOCAL_PATH, non-recursively.
###############################################################################

# $1 : directory relative to LOCAL_PATH to search
# $2 : extension to search (.c, .cpp ...)
all-files-in = $(strip \
	$(patsubst ./%,%, \
	$(shell cd $(LOCAL_PATH); \
		ls $1/*$2) \
	))

# $1 : directory relative to LOCAL_PATH to search
all-c-files-in = $(call all-files-in,$1,.c)
all-cpp-files-in = $(call all-files-in,$1,.cpp)
all-cxx-files-in = $(call all-files-in,$1,.cxx)
all-cc-files-in = $(call all-files-in,$1,.cc)

###############################################################################
## Check compilation flags for some forbidden stuff.
## $1 : variable to check (its name, not its value).
## $2 : list of flags to check for their presence in $1 (can be a pattern).
## $3 : message to display in case of error.
###############################################################################
check-flags = \
	$(eval __r := $(filter $2,$($1))) \
	$(if $(__r),$(error $(LOCAL_PATH): $1 contains $(__r) : $3))

###############################################################################
## Add debug flags to current LOCAL_xxx macros.
###############################################################################
add-debug-flags = \
	$(eval __debug_CFLAGS := $(call module-get-debug-flags,$(LOCAL_MODULE),CFLAGS)) \
	$(eval __debug_CXXFLAGS := $(call module-get-debug-flags,$(LOCAL_MODULE),CXXFLAGS)) \
	$(eval __debug_LDFLAGS := $(call module-get-debug-flags,$(LOCAL_MODULE),LDFLAGS)) \
	$(if $(strip $(__debug_CFLAGS)), \
		$(info Debug: Adding '$(__debug_CFLAGS)' to '$(LOCAL_MODULE)' CFLAGS) \
		$(eval LOCAL_CFLAGS += $(__debug_CFLAGS)) \
	) \
	$(if $(strip $(__debug_CXXFLAGS)), \
		$(info Debug: Adding '$(__debug_CXXFLAGS)' to '$(LOCAL_MODULE)' CXXFLAGS) \
		$(eval LOCAL_CXXFLAGS += $(__debug_CXXFLAGS)) \
	) \
	$(if $(strip $(__debug_LDFLAGS)), \
		$(info Debug: Adding '$(__debug_LDFLAGS)' to '$(LOCAL_MODULE)' LDFLAGS) \
		$(eval LOCAL_LDFLAGS += $(__debug_LDFLAGS)) \
	)

###############################################################################
## Normalize a list of includes. It adds -I if needed.
## $1 : list of includes
###############################################################################
normalize-c-includes = $(strip \
	$(foreach __inc,$1, \
		$(addprefix -I,$(patsubst -I%,%,$(__inc))) \
	))

# Same but convert path relative to top
normalize-c-includes-rel = $(strip \
	$(foreach __inc,$1, \
		$(addprefix -I,$(call path-from-top,$(patsubst -I%,%,$(__inc)))) \
	))

# Same as normalize-c-includes but uses the -isystem instead of -I flag
# Note gcc 4.4.3 of android seems to mess things up when this flag is uses in C++
normalize-system-c-includes = $(strip \
	$(if $(call streq,$(TARGET_CC_VERSION),4.4.3), \
		$(call normalize-c-includes,$1), \
		\
		$(foreach __inc,$1, \
			$(addprefix -isystem,$(patsubst -I%,%,$(__inc))) \
		)) \
	)

# Same as normalize-c-includes-rel but uses the -isystem instead of -I flag
# Note gcc 4.4.3 of android seems to mess things up when this flag is uses in C++
normalize-system-c-includes-rel = $(strip \
	$(if $(call streq,$(TARGET_CC_VERSION),4.4.3), \
		$(call normalize-c-includes-rel,$1), \
		\
		$(foreach __inc,$1, \
			$(addprefix -isystem ,$(call path-from-top,$(patsubst -I%,%,$(__inc)))) \
		)) \
	)

###############################################################################
## Copy files helpers.
###############################################################################

# Get full source path for the copy.
# $1 : path relative to LOCAL_PATH, or directly the full path.
copy-get-src-path = $(strip \
	$(if $(call is-path-absolute,$1), \
		$1,$(addprefix $(LOCAL_PATH)/,$1) \
	))

# Get full destination path for the copy.
# $1 : path relative to TARGET_OUT_STAGING, or directly the full path.
copy-get-dst-path = $(strip \
	$(if $(call is-path-absolute,$1), \
		$1,$(addprefix $(TARGET_OUT_STAGING)/,$1) \
	))

# Get full destination path for the copy in a host module.
# $1 : path relative to HOST_OUT_STAGING, or directly the full path.
copy-get-dst-path-host = $(strip \
	$(if $(call is-path-absolute,$1), \
		$1,$(addprefix $(HOST_OUT_STAGING)/,$1) \
	))

###############################################################################
## Setup installed headers in LOCAL_COPY_FILES and LOCAL_EXPORT_PREREQUISITES.
## $1 : module name.
###############################################################################
install-headers-setup = \
	$(foreach __pair,$(__modules.$1.INSTALL_HEADERS), \
		$(eval __pair2 := $(subst :,$(space),$(__pair))) \
		$(eval __w1 := $(word 1,$(__pair2))) \
		$(eval __w2 := $(word 2,$(__pair2))) \
		$(if $(__w2),$(empty),$(eval __w2 := usr/include/)) \
		$(eval __src := $(call copy-get-src-path,$(__w1))) \
		$(if $(call is-module-host,$1), \
			$(eval __dst := $(call copy-get-dst-path-host,$(__w2))), \
			$(eval __dst := $(call copy-get-dst-path,$(__w2))) \
		) \
		$(if $(call is-path-dir,$(__dst)), \
			$(eval __dst := $(__dst)$(notdir $(__src))) \
		) \
		$(eval __modules.$1.COPY_FILES += $(__w1):$(__w2)) \
		$(eval __modules.$1.EXPORT_PREREQUISITES += $(__dst)) \
	)

###############################################################################
## Setup conditional libraries. It looks for pairs <var>:<lib> in
## LOCAL_CONDITIONAL_LIBRARIES and add <lib> in LOCAL_LIBRARIES if <var> is
## defined.
## If <var> equals 'OPTIONAL', <lib> is added if it is in the build config.
## $1 : module name.
###############################################################################
conditional-libraries-setup = \
	$(foreach __pair,$(__modules.$1.CONDITIONAL_LIBRARIES), \
		$(eval __pair2 := $(subst :,$(space),$(__pair))) \
		$(eval __w1 := $(word 1,$(__pair2))) \
		$(eval __w2 := $(word 2,$(__pair2))) \
		$(if $(call streq,$(__w1),OPTIONAL), \
			$(if $(call is-module-in-build-config,$(__w2)), \
				$(eval __modules.$1.LIBRARIES += $(__w2)) \
			) \
			, \
			$(if $(call is-var-defined,$(__w1)), \
				$(eval __modules.$1.LIBRARIES += $(__w2)) \
			) \
		) \
	)

###############################################################################
## Filter a list of modules tp keep only internal or external ones.
## $1 : list of modules to filter.
###############################################################################
filter-get-internal-modules = $(strip \
	$(foreach __mod,$1, \
		$(if $(call is-module-external,$(__mod)),$(empty),$(__mod)) \
	))

filter-get-external-modules = $(strip \
	$(foreach __mod,$1, \
		$(if $(call is-module-external,$(__mod)),$(__mod)) \
	))

###############################################################################
# Manipulation of .config files based on the Kconfig infrastructure.
###############################################################################
define kconfig-enable-opt
	@sed -i.bak -e "/\\<$1\\>/d" $2 && rm -f $2.bak
	@echo "$1=y" >> $2
endef

define kconfig-set-opt
	@sed -i.bak -e "/\\<$1\\>/d" $3 && rm -f $3.bak
	@echo "$1=$2" >> $3
endef

define kconfig-disable-opt
	@sed -i.bak -e "/\\<$1\\>/d" $2 && rm -f $2.bak
	@echo "# $1 is not set" >> $2
endef

###############################################################################
## Copy a macro.
## $1 : destination variable.
## $1 : source variable.
## This works by reevaluating the content of the macro in a new variable.
###############################################################################
macro-copy = $(eval define $1$(endl)$(value $2)$(endl)endef)

###############################################################################
## Compare 2 macros.
## $1 : first variable.
## $2 : second variable.
###############################################################################
macro-compare = $(call streq,$(value $1),$(value $2))

###############################################################################
## Determine if a macro is empty.
## $1 : name of macro.
###############################################################################
macro-is-empty = $(call not,$(value $1))

###############################################################################
## Execute commands of a macro.
## $1 : Type of commands to execute. Ex : AUTOTOOLS_CMD_CONFIGURE...
## $2 : default macro if $1 is empty.
##
## Note : if the content of the variable is empty, the default one will be used.
## Note : we access macros from the module database because we can't create
##        PRIVATE_XXX target-specific variables for them.
###############################################################################
macro-exec-cmd = \
	$(eval __var := __modules.$(PRIVATE_MODULE).$1) \
	$(if $(value $(__var)), \
		$($(__var)), \
		$(if $2,$($2)) \
	)

###############################################################################
## Call custom macros.
## $1 : module name
##
## The LOCAL_xxx variables of the modules are first restored and at the end
## put back in database.
##
## It verifies that it really exists but with no message at this point.
## This is because this is called early in parsing before computing all
## dependencies and so before we know exactly what needs to be built.
##
## To call the macros with argument, we 'eval' a string that will contain the
## 'call'. It is a bit diffent of standard uses of 'eval' where we evaluate the
## result of the call. This is done so that the variable containing the parameters
## is expected before the call is made.
## After we still 'eval' the result that can contains additional rules.
##
## Note: you can add $(info xx$(__tmp)xx) before the sencon eval to debug what
## is internally generated by the macro call.
###############################################################################
exec-custom-macro = \
	$(call module-restore-locals,$1) \
	$(foreach __entry,$(LOCAL_CUSTOM_MACROS), \
		$(eval __entry2 := $(subst :,$(space),$(__entry))) \
		$(eval __w1 := $(word 1,$(__entry2))) \
		$(eval __w2 := $(word 2,$(__entry2))) \
		$(if $(call is-var-defined,$(__w1)), \
			$(eval __tmp := $$(call $(__w1),$(__w2))) \
			$(eval $(__tmp)) \
		) \
	) \
	$(foreach __var,$(vars-LOCAL), \
		$(eval __modules.$(__mod).$(__var) := $(LOCAL_$(__var))) \
	) \

###############################################################################
## Check that custom macros of a module are well defined.
## $1 : module name.
###############################################################################
check-custom-macro = \
	$(foreach __entry,$(__modules.$1.CUSTOM_MACROS), \
		$(eval __entry2 := $(subst :,$(space),$(__entry))) \
		$(eval __w1 := $(word 1,$(__entry2))) \
		$(eval __w2 := $(word 2,$(__entry2))) \
		$(if $(call is-var-undefined,$(__w1)), \
			$(warning $(__modules.$1.PATH): module '$1' \
				uses undefined custom macro '$(__w1)'), \
		) \
	)

###############################################################################
## Macros to be called before and after inclusion of user makefiles.
## It checks that user makefile does not overwrite internal variables.
##
## Use macro-copy/macro-compare in case some variables contains stuff that
## should not be done while being evaluated.
## For example the variable TARGET_GLOBAL_CFLAGS_thumb may contains an error
## message displayed when used while TARGET_DEFAULT_ARM_MODE is 'arm'.
###############################################################################

# Old variables still suported but no more in vars-LOCAL or macros-LOCAL
__compat-vars-LOCAL := \
	AUTOTOOLS_ARCHIVE \
	AUTOTOOLS_VERSION \
	AUTOTOOLS_SUBDIR \
	AUTOTOOLS_PATCHES \
	AUTOTOOLS_CMD_UNPACK \
	AUTOTOOLS_CMD_POST_UNPACK \
	AUTOTOOLS_COPY_TO_BUILD_DIR \

# All allowed variables
__all-vars-LOCAL := \
	$(vars-LOCAL) \
	$(macros-LOCAL) \
	$(__compat-vars-LOCAL)

# Get all defined LOCAL_XXX variables
__get-defined-local-vars = $(filter LOCAL_%,$(.VARIABLES))

# Check all defined LOCAL_XXX variables
__check-local-vars = \
	$(foreach __v,$(__get-defined-local-vars), \
		$(call __check-local-var,$1,$(__v)) \
	)

# Check a LOCAL_XXX variable for validity, clear it if unknown to the system
__check-local-var = $(if $(value $2), \
	$(if $(filter $(patsubst LOCAL_%,%,$2),$(__all-vars-LOCAL)),$(empty), \
		$(info $1: defining unknown LOCAL variable $2) \
		$(eval $2 :=) \
	))

# This variable will hold the list of modules with global prerequisites
# Those module will always have their rule loaded in case the global
# prerequisites need to be updated
__modules-with-global-prerequisites :=

# Save TARGET_XXX variables
# We save GLOBAL_PREREQUISITES here and we check it at each module-add
user-makefile-before-include = \
	$(eval __var := GLOBAL_PREREQUISITES) \
	$(call macro-copy,saved-TARGET_$(__var),TARGET_$(__var)) \
	$(foreach __var,$(vars-TARGET), \
		$(if $(call is-var-defined,TARGET_$(__var)), \
			$(call macro-copy,saved-TARGET_$(__var),TARGET_$(__var)) \
		) \
	)

# Make sure that TARGET_XXX have not been modified
user-makefile-after-include = \
	$(foreach __var,$(vars-TARGET), \
		$(if $(call is-var-defined,TARGET_$(__var)), \
			$(if $(call macro-compare,TARGET_$(__var),saved-TARGET_$(__var)),$(empty), \
				$(warning $1: attempt to modify TARGET_$(__var)) \
				$(call macro-copy,TARGET_$(__var),saved-TARGET_$(__var)) \
			) \
		) \
	) \
	$(call __check-local-vars,$1)

###############################################################################
## Print some banners.
## $1 : operation.
## $2 : module.
## $3 : file.
###############################################################################

CLR_TOOL   := $(CLR_PURPLE)
CLR_MODULE := $(CLR_CYAN)
CLR_FILE   := $(CLR_YELLOW)

print-banner1 = \
	@echo "$(CLR_TOOL)$1:$(CLR_DEFAULT) $(CLR_MODULE)$2$(CLR_DEFAULT) <= $(CLR_FILE)$3$(CLR_DEFAULT)"

print-banner2 = \
	@echo "$(CLR_TOOL)$1:$(CLR_DEFAULT) $(CLR_MODULE)$2$(CLR_DEFAULT) => $(CLR_FILE)$3$(CLR_DEFAULT)"

###############################################################################
## Macro called during link.
## $1 : module name.
## $2 : name of the binary being linked.
## $3 : list of object files as well as static libraries used during link.
## It returns additional object files to add in link.
##
## The pbuild hook will be given the list of all dependencies of the module.
###############################################################################
link-hook = $(strip \
	$(if $(PRIVATE_PBUILD_HOOK), \
		$(eval __depsdata := $(empty)) \
		$(if $(call streq,$(TARGET_PBUILD_HOOK_USE_DESCRIBE),1), \
			$(foreach __lib,$(sort $1 $(__modules.$1.depends.all)), \
				$(eval __depsdata += $(__lib):$(__modules.$(__lib).PATH)) \
			)\
		) \
		$(shell $(BUILD_SYSTEM)/pbuild-hook/pbuild-link-hook.sh \
			"$(PRIVATE_NM)" "$(PRIVATE_CC) $(TARGET_GLOBAL_CFLAGS)" \
			$1 $2 "$(__depsdata)" $3 \
		) \
	))

###############################################################################
## Add a section in a binary with list of dependencies and their revision.
## The revision of this module is also added a the start of the list.
## The section will simply be a list of lines in the form lib:revision.
## Note : shall only be used in a rule because it uses $@
###############################################################################

define add-depends-section
$(eval __depsdata := $(empty))
$(foreach __lib,$(PRIVATE_MODULE) $(__modules.$(PRIVATE_MODULE).depends.all), \
	$(eval __depsdata += $(__lib):$(call module-get-revision,$(__lib))) \
)
$(eval __depsdata := $(subst $(space),\n,$(strip $(__depsdata))))
@( \
	__tmpfile=$$(mktemp tmp.XXXXXXXXXX); \
	/bin/echo -e "$(__depsdata)" > $${__tmpfile}; \
	$(PRIVATE_OBJCOPY) --add-section \
		$(TARGET_DEPENDS_SECTION_NAME)=$${__tmpfile} $@; \
	rm -f $${__tmpfile}; \
)
endef

###############################################################################
## Add a section in a binary with a build id.
## This is a `sha1` of all sections that are loadable at runtime and with data
## in the binary. This section is kept after stripping and the `sha1` can be
## recomputed on the original and stripped binary and still produce the same
## `sha1`. This can be used to identify the non-stripped binary based on the
## stripped one.
## Note : shall only be used in a rule because it uses $@
###############################################################################

define add-buildid-section
@( \
	$(BUILD_SYSTEM)/scripts/addbuildid.py \
	--objcopy=$(PRIVATE_OBJCOPY) \
	--section-name=$(TARGET_BUILDID_SECTION_NAME) $@ \
)
endef

###############################################################################
## Copy license files from $1 to $2.
## It will copy [.]MODULE_LICENSE* and [.]MODULE_NAME* files, as well as
## NOTICE or COPYING files to help police.
## $1 : source directory.
## $2 : destination directory.
###############################################################################
__license-pattern := \
	MODULE_LICENSE* .MODULE_LICENSE* MODULE_NAME* .MODULE_NAME* \
	NOTICE COPYING.LIB COPYING LICENSE LICENSE.txt
define copy-license-files
@( \
	files="$(wildcard $(addprefix $1/,$(__license-pattern)))"; \
	if [ "$${files}" != "" ]; then mkdir -p $2; cp -af $${files} $2; fi; \
)
endef

###############################################################################
## Fix a .d file with compilation dependencies.
## It will ensure that full paths are specified.
## $1 : file to fix.
###############################################################################
define fix-deps-file
@( \
	[ ! -f $1 ] || (sed -i.bak \
		-e 's| \([^/\\: ]\)| $(TOP_DIR)/\1|g' \
		-e 's|^\([^/\\: ]\)|$(TOP_DIR)/\1|g' \
		$1 && rm -f $1.bak) \
)
endef

###############################################################################
## Commands for copying files.
###############################################################################

# Define a rule to copy a file. For use via $(eval) so use $$@ and $$<.
# use '-a' to preserve permissions/links
# $(1) : source file
# $(2) : destination file
define copy-one-file
$(2): $(1)
	@echo "Copy: $$(call path-from-top,$$<) => $$(call path-from-top,$$@)"
	@mkdir -p $$(dir $$@)
	$(Q)rm -f $$@ && cp -a $$< $$@
endef

###############################################################################
## Commands for creating links.
###############################################################################

# Define a rule to create a link. For use via $(eval) so use $$@ and $$<.
# $(1) : name of link
# $(2) : target of link
define create-one-link
$(1):
	@echo "Link: $$(call path-from-top,$$@) => $(2)"
	@mkdir -p $$(dir $$@)
	$(Q)rm -f $$@ && ln -s $(2) $$@
endef

###############################################################################
## Commands callable from user makefiles.
###############################################################################

# Get local path
local-get-path = $(call my-dir)

# Get build directory (need to check LOCAL_HOST_MODULE because module name
# does not yet contain the 'host.' prefix)
local-get-build-dir = $(strip \
	$(if $(LOCAL_HOST_MODULE), \
		$(call module-get-build-dir-host,$(LOCAL_HOST_MODULE)) \
		, \
		$(call module-get-build-dir,$(LOCAL_MODULE)) \
	))

# Register custom macro
# $1 : name of the macro to register
local-register-custom-macro = \
	$(eval __custom-macros += $1)

# Register a prebuilt module unless a setting explicitly override it
local-register-prebuilt-overridable = \
	$(eval __var := prebuilt.$(LOCAL_MODULE).override) \
	$(if $(and $(call is-var-defined,$(__var)),$(call streq,$($(__var)),1)), \
		$(info Prebuilt module $(LOCAL_MODULE) marked as overriden) ,\
		$(eval include $(BUILD_PREBUILT)) \
	)
