###############################################################################
## @file main.mk
## @author Y.M. Morgan
## @date 2011/05/14
##
## Main Makefile.
###############################################################################

###############################################################################
## General setup.
###############################################################################

# Alchemy version
ALCHEMY_VERSION_MAJOR := 1
ALCHEMY_VERSION_MINOR := 3
ALCHEMY_VERSION_REV   := 3
ALCHEMY_VERSION := $(ALCHEMY_VERSION_MAJOR).$(ALCHEMY_VERSION_MINOR).$(ALCHEMY_VERSION_REV)

# Make sure SHELL is correctly set
SHELL := /bin/bash

# Turns off suffix rules built into make
.SUFFIXES:

# Turns off the RCS / SCCS implicit rules of GNU Make
%: RCS/%,v
%: RCS/%
%: %,v
%: s.%
%: SCCS/s.%

# Overridable settings
V ?= 0
W ?= 0
F ?= 0
USE_CLANG ?= 0
USE_CCACHE ?= 0
USE_SCAN_CACHE ?= 0
USE_COLORS ?= 0
USE_GIT_REV ?= 1
USE_CONFIG_CHECK ?= 1
USE_COVERAGE ?= 0
USE_ADDRESS_SANITIZER ?= 0
USE_MEMORY_SANITIZER ?= 0
USE_THREAD_SANITIZER ?= 0
USE_UNDEFINED_SANITIZER ?= 0
USE_AUTOTOOLS_CACHE ?= 0
USE_AUTO_LIB_PREFIX ?= 0
USE_LINK_MAP_FILE ?= 1

# TODO: remove any reference to this in atom.mk
ALCHEMY_SUPPORT_HOST_MODULE := 1

# Quiet command if V is 0
ifeq ("$(V)","0")
  Q := @
  MAKEFLAGS += --no-print-directory
else
  Q :=
endif

# Remove --warn-undefined-variables flags for sub-make invocations
# FIXME: this has the side effect of disabling other stuff as well (like -j)...
#ifdef MAKEFLAGS
#  override MAKEFLAGS := $(filter-out --warn-undefined-variables,$(MAKEFLAGS))
#endif

# This is the default target.  It must be the first declared target.
all:

# To avoid use of undefined variable, force our default goal
MAKECMDGOALS ?= all

# Used to force goals to build.
.PHONY: .FORCE
.FORCE:

###############################################################################
###############################################################################

# Figure out where we are
# It returns the full path without trailing '/'
my-dir = $(abspath $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST)))))
BUILD_SYSTEM := $(call my-dir)

# Import use colors from env (required before including defs.mk)
ifdef ALCHEMY_USE_COLORS
  USE_COLORS := $(ALCHEMY_USE_COLORS)
endif

###############################################################################
## Env system setup.
###############################################################################
include $(BUILD_SYSTEM)/variables.mk
include $(BUILD_SYSTEM)/defs.mk

# Make sure all TARGET_xxx variables that we received does not have trailing
# spaces or end of line
$(foreach __var,$(vars-TARGET), \
	$(if $(call is-var-defined,TARGET_$(__var)), \
		$(eval TARGET_$(__var) := $(strip $(TARGET_$(__var)))) \
	) \
)

USER_MAKEFILE_NAME := atom.mk
include $(BUILD_SYSTEM)/target-setup.mk
include $(BUILD_SYSTEM)/toolchain-setup.mk

###############################################################################
## Default rules of makefile add TARGET_ARCH in CFLAGS.
## As it is not the way we use it, prevent export of this variable
###############################################################################
# Unexport does not work when TARGET_ARCH is set on command line, force clearing it
MAKEOVERRIDES ?=
MAKEOVERRIDES := $(filter-out TARGET_ARCH=%,$(MAKEOVERRIDES))
unexport TARGET_ARCH

###############################################################################
## Display configuration.
###############################################################################
msg = $(info $(CLR_CYAN)$1$(CLR_DEFAULT))
$(info ----------------------------------------------------------------------)
$(call msg,+ ALCHEMY_WORKSPACE_DIR = $(ALCHEMY_WORKSPACE_DIR))
$(call msg,+ TARGET_PRODUCT = $(TARGET_PRODUCT))
$(call msg,+ TARGET_PRODUCT_VARIANT = $(TARGET_PRODUCT_VARIANT))
$(call msg,+ TARGET_OS = $(TARGET_OS))
$(call msg,+ TARGET_OS_FLAVOUR = $(TARGET_OS_FLAVOUR))
$(call msg,+ TARGET_LIBC = $(TARGET_LIBC))
$(call msg,+ TARGET_ARCH = $(TARGET_ARCH))
$(call msg,+ TARGET_CPU = $(TARGET_CPU))
$(call msg,+ TARGET_OUT = $(TARGET_OUT))
$(call msg,+ TARGET_CONFIG_DIR = $(TARGET_CONFIG_DIR))
$(call msg,+ TARGET_CC_PATH = $(TARGET_CC_PATH))
$(call msg,+ TARGET_CC_VERSION = $(TARGET_CC_VERSION))
$(info ----------------------------------------------------------------------)

# Do some checking
include $(BUILD_SYSTEM)/check.mk

###############################################################################
## Build system setup.
###############################################################################

# Set this variable to 1 to skip a lot of things like dependencies check and
# config check. Useful if user only want some internal query or configure
# something.
SKIP_DEPS_AND_CHECKS := 0

# Set this variable to 1 to skip deps and checks of external modules built
# outside this build system (basically it force remaking them by removing
# their .done file).
SKIP_EXT_DEPS_AND_CHECKS := 0

# Silently skip config check (in contrast to USE_CONFIG_CHECK that warn)
SKIP_CONFIG_CHECK := 0

# Register and setup all module classes
include $(BUILD_SYSTEM)/classes/setup.mk

# Setup configuration definitions
include $(BUILD_SYSTEM)/config-defs.mk

# Makefile that will clear all LOCAL_XXX variable before registering a new module
CLEAR_VARS := $(BUILD_SYSTEM)/clearvars.mk

# Shall be defined before including user makefiles
AUTOCONF_MERGE_FILE := $(TARGET_OUT_BUILD)/autoconf-merge.h

# Define some target class
__clobber-targets := clobber clean dirclean final-clean
__query-targets := scan help help-modules dump dump-depends dump-xml build-graph
__config-targets := config config-check config-update xconfig menuconfig nconfig

# Do not check config if we are cloberring or doing some query or configuration
__skip-config-check-targets := $(__clobber-targets) $(__query-targets) $(__config-targets)
ifneq ("$(call is-targets-in-make-goals,$(__skip-config-check-targets))","")
  SKIP_CONFIG_CHECK := 1
endif

# Skip some steps for some make goals. No optimization if 'all' is also given
ifeq ("$(call is-targets-in-make-goals,all)","")
ifneq ("$(findstring -clean,$(MAKECMDGOALS))","")
  SKIP_DEPS_AND_CHECKS := 1
endif
ifneq ("$(filter %-dirclean %-path,$(MAKECMDGOALS))","")
  SKIP_DEPS_AND_CHECKS := 1
endif
ifneq ("$(filter %-config %-xconfig %-menuconfig %-nconfig,$(MAKECMDGOALS))","")
  SKIP_CONFIG_CHECK := 1
endif
endif

# Skip external checks if requested
ifeq ("$(TARGET_FORCE_EXTERNAL_CHECKS)","0")
  SKIP_EXT_DEPS_AND_CHECKS := 1
endif

# No reason to do external checks if we are skipping our own deps and checks...
ifneq ("$(SKIP_DEPS_AND_CHECKS)","0")
  SKIP_EXT_DEPS_AND_CHECKS := 1
endif

###############################################################################
## Makefile scan and includes.
###############################################################################

# Makefile with the list of all makefiles available and include them
USER_MAKEFILES_CACHE := $(TARGET_OUT_BUILD)/makefiles.mk
USER_MAKEFILES :=

# Command to find files
find-cmd := $(BUILD_SYSTEM)/scripts/findfiles.py \
	--prune=.git --prune=.repo \
	--prune=$(TARGET_OUT) \
	--prune=$(TARGET_OUT_BUILD) \
	--prune=$(TARGET_OUT_STAGING) \
	--prune=$(TARGET_OUT_FINAL) \
	--prune=$(BUILD_SYSTEM) \
	$(foreach __d,$(TARGET_SCAN_PRUNE_DIRS),--prune=$(__d)) \
	$(foreach __d,$(TARGET_SCAN_ADD_DIRS),--add=$(__d)) \
	$(foreach __d,$(TARGET_SDK_DIRS),--prune=$(__d)) \
	$(if $(call streq,$(TARGET_SCAN_FOLLOW_LINKS),1),--follow-links) \
	$(TOP_DIR) \
	$(USER_MAKEFILE_NAME)

# Create a file that will contain all user makefiles available
# Make sure that atom.mk from sdk are included first so they can be overriden
# Put target/os specific packages AFTER sdk for same reason
create-user-makefiles-cache = \
	rm -f $(USER_MAKEFILES_CACHE); \
	mkdir -p $(dir $(USER_MAKEFILES_CACHE)); \
	touch $(USER_MAKEFILES_CACHE); \
	files="$(addsuffix /$(USER_MAKEFILE_NAME),$(TARGET_SDK_DIRS)) \
		$(BUILD_SYSTEM)/targets/packages.mk \
		$(BUILD_SYSTEM)/toolchains/packages.mk \
		`$(find-cmd)` \
	"; \
	( \
		echo "\$$(info Found `echo $$files | wc -w` makefiles)"; \
		for f in $$files; do \
			echo "USER_MAKEFILE := $$f"; \
			echo "USER_MAKEFILES += \$$(USER_MAKEFILE)"; \
			echo "\$$(call user-makefile-before-include,\$$(USER_MAKEFILE))"; \
			$(if $(call strneq,$(V),0),echo "\$$(info \$$(USER_MAKEFILE))";) \
			echo "include \$$(USER_MAKEFILE)"; \
			echo "\$$(call user-makefile-after-include,\$$(USER_MAKEFILE))"; \
		done \
	) >> $(USER_MAKEFILES_CACHE);

# Determine if we need to re-create the cache
do-create-cache := 0
ifeq ("$(USE_SCAN_CACHE)","0")
  do-create-cache := 1
else ifneq ("$(call is-targets-in-make-goals,scan)","")
  do-create-cache := 1
else
  $(warning Using scan cache, some $(USER_MAKEFILE_NAME) might be missing...)
endif

ifneq ("$(do-create-cache)","0")

# Force regeneration of cache and include scanned files
# Assignation to dummy variable is to ignore any output of shell command
dummy := $(shell $(create-user-makefiles-cache))
include $(USER_MAKEFILES_CACHE)

else

# Force not checking config if cache is not present. This is to avoid some
# warnings due to the fact that no module could be registered. Another parsing
# of Alchemy will anyway be triggered after generation of the cache.
ifeq ("$(wildcard $(USER_MAKEFILES_CACHE))","")
  SKIP_CONFIG_CHECK := 1
endif

# Include makefile containing all available makefiles
# If it does not exists, it will trigger its creation
ifeq ("$(call is-targets-in-make-goals,scan $(__clobber-targets))","")
  -include $(USER_MAKEFILES_CACHE)
endif

endif

# Rule that will trigger creation of list of makefiles when needed
$(USER_MAKEFILES_CACHE):
	@$(create-user-makefiles-cache)

# Rule to force creation of list of makefiles
# This doesn't do a a lot, everything is done above. Scan in make goals
# triggers the creation of the cache of makefiles
.PHONY: scan
scan:
	@echo "Scan done"

###############################################################################
## Module dependencies generation.
###############################################################################

# Now that all modules have been registered, sort the variable
__modules := $(sort $(__modules))
$(info Found $(words $(__modules)) modules)

# Execute custom macros of modules. Done on all modules because it can modify
# the dependencies.
$(foreach __mod,$(__modules), \
	$(call exec-custom-macro,$(__mod)) \
)

# Recompute all dependencies between modules
$(info Computing modules dependencies...)
$(call modules-compute-depends)

ifdef TARGET_TEST
  $(call modules-enable-test-depends)
endif

# All modules
ALL_MODULES := $(__modules)

# All modules to actually build (without host modules)
ALL_BUILD_MODULES := $(strip \
	$(foreach __mod,$(ALL_MODULES), \
		$(if $(call is-module-host,$(__mod)),$(empty), \
			$(if $(call is-module-in-build-config,$(__mod)),$(__mod)) \
		) \
	))

# If no config file available, remove modules with unknown dependencies
ifeq ("$(GLOBAL_CONFIG_FILE_AVAILABLE)","0")
$(foreach __mod,$(ALL_BUILD_MODULES), \
	$(foreach __lib,$(call module-get-build-depends,$(__mod)), \
		$(if $(call is-module-registered,$(__lib)),$(empty), \
			$(info Disabling $(__mod): has unknown dependency $(__lib)) \
			$(eval ALL_BUILD_MODULES := $(filter-out $(__mod),$(ALL_BUILD_MODULES))) \
			$(call module-force-disabled,$(__mod)) \
		) \
	) \
	$(foreach __host,$(__modules.$(__mod).DEPENDS_HOST_MODULES), \
		$(if $(call is-module-registered,$(__host)),$(empty), \
			$(info Disabling $(__mod): has unknown dependency $(__host)) \
			$(eval ALL_BUILD_MODULES := $(filter-out $(__mod),$(ALL_BUILD_MODULES))) \
			$(call module-force-disabled,$(__mod)) \
		) \
	) \
)
endif

# All host modules to actually build (based on built modules)
# Force defining the CONFIG_ALCHEMY_BUILD_xxx variable to 'y' so the module is
# now considered as being part of the config
ALL_BUILD_MODULES_HOST := $(call modules-get-required-host,$(ALL_BUILD_MODULES))
$(foreach __mod,$(ALL_BUILD_MODULES_HOST), \
	$(eval CONFIG_ALCHEMY_BUILD_$(call module-get-define,$(__mod)) := y) \
)

# Check dependencies and variables of modules
ifeq ("$(SKIP_DEPS_AND_CHECKS)","0")
ifeq ("$(SKIP_CONFIG_CHECK)","0")
  $(info Checking modules dependencies...)
  $(call modules-check-depends)
  $(call modules-check-variables)
endif
endif

# Generate files with module list
$(shell mkdir -p $(TARGET_OUT_BUILD))
$(shell echo "$(ALL_MODULES)" > $(TARGET_OUT_BUILD)/modules)
$(shell echo "$(ALL_BUILD_MODULES)" > $(TARGET_OUT_BUILD)/build-modules)

###############################################################################
## Module rules generation.
###############################################################################

# Configuration rules (once module database is built)
include $(BUILD_SYSTEM)/config-rules.mk

# Now, really generate rules for modules.
__modlist := $(empty)

# Completely skip this for simple queries or clobber.
ifeq ("$(call is-targets-in-make-goals,$(__query-targets) $(__clobber-targets))","")

# Check that, if a registered module is specified in goals,
# it is in the build config
$(foreach __mod,$(ALL_MODULES), \
	$(if $(call is-module-in-make-goals,$(__mod)), \
		$(if $(call is-module-host,$(__mod)), \
			$(if $(call is-not-item-in-list,$(__mod),$(ALL_BUILD_MODULES_HOST)), \
				$(eval ALL_BUILD_MODULES_HOST += $(__mod)) \
			), \
			$(if $(call is-not-item-in-list,$(__mod),$(ALL_BUILD_MODULES)), \
				$(info $(__mod) is not enabled in the config) \
				$(eval ALL_BUILD_MODULES += $(__mod) \
					$(call module-get-build-depends,$(__mod)) \
				) \
			) \
		) \
	) \
)

$(info Generating rules...)

# Determine the list of modules to really include
# If a module is specified in goals, only include this one and its dependencies.
# If 'all' or 'check' is also given do not do the filter
# For meta packages, also get config dependencies (for build/clean shortcuts)
ifeq ("$(call is-targets-in-make-goals,all check all-clean all-dirclean all-doc all-codecheck)","")
$(foreach __mod,$(ALL_BUILD_MODULES) $(ALL_BUILD_MODULES_HOST), \
	$(if $(call is-module-in-make-goals,$(__mod)), \
		$(eval __modlist += $(__mod)) \
		$(eval __modlist += $(call module-get-build-depends,$(__mod))) \
		$(if $(call is-module-meta-package,$(__mod)), \
			$(foreach __mod2,$(call module-get-config-depends,$(__mod)), \
				$(eval __modlist += $(__mod2)) \
				$(eval __modlist += $(call module-get-build-depends,$(__mod2))) \
			) \
			$(foreach __mod2,$(sort $(__modlist)), \
				$(if $(call is-module-registered,$(__mod2)),$(empty), \
					$(info Meta package $(__mod) requires unknown module $(__mod2)) \
					$(eval __modlist := $(filter-out $(__mod2),$(__modlist))) \
				) \
			) \
		) \
	) \
)
else
__modlist := $(ALL_BUILD_MODULES) $(ALL_BUILD_MODULES_HOST)
endif

# If autoconf-merge is present, force including all modules having a config .in
ifneq ("$(filter autoconf-merge,$(__modlist))","")
$(foreach __mod,$(ALL_BUILD_MODULES), \
	$(eval __modlist += \
		$(if $(__modules.$(__mod).CONFIG_FILES),$(__mod)) \
	) \
)
endif

# Add required host modules
# Sorting will ensure they appear only once as well
__modlist += $(call modules-get-required-host,$(__modlist))
__modlist := $(sort $(__modlist))

# Now, generate rules of selected modules, always include modules with global
# prerequisites
$(foreach __mod,$(sort $(__modlist) $(__modules-with-global-prerequisites)), \
	$(eval LOCAL_MODULE := $(__mod)) \
	$(eval include $(BUILD_SYSTEM)/classes/rules.mk) \
)

endif

# Once all module rules have been generated, make sure nobody will reference
# LOCAL_XXX variables anymore.
# In commands, PRIVATE_XXX variables shall be used.
$(foreach __var,$(vars-LOCAL) $(macros-LOCAL), \
	$(eval override LOCAL_$(__var) = \
		$$(error Do NOT use LOCAL_$(__var) in commands)) \
)

###############################################################################
## Rule to merge autoconf.h files.
## Can NOT be in pbuild-hook/atom.mk because we need complete database for
## the rules below.
###############################################################################

# List of all available autoconf.h files
__autoconf-list := $(strip \
	$(foreach __mod,$(ALL_BUILD_MODULES), \
		$(call module-get-autoconf,$(__mod)) \
	))

# Concatenate all in one
$(AUTOCONF_MERGE_FILE): $(__autoconf-list)
	@echo "Generating autoconf-merge.h"
	@mkdir -p $(dir $@)
	@rm -f $@
	@touch $@
	@for f in $^; do cat $$f >> $@; done

###############################################################################
## Main rules.
###############################################################################

# Poll variable contents after every helpers have been loaded
.PHONY: var-%
var-%:
	@echo $*=$($*)

.PHONY: all
all: $(ALL_BUILD_MODULES) $(ALL_BUILD_MODULES_HOST)
	@echo "Done building all"

.PHONY: all-doc
all-doc: $(foreach __mod,$(ALL_BUILD_MODULES),$(if $(call is-module-prebuilt,$(__mod)),$(empty),$(__mod)-doc))
	@echo "Done all-doc"

.PHONY: all-codecheck
all-codecheck: $(foreach __mod,$(ALL_BUILD_MODULES),$(if $(call is-module-prebuilt,$(__mod)),$(empty),$(__mod)-codecheck))
	@echo "Done all-codecheck"

.PHONY: all-cloc
all-cloc: $(foreach __mod,$(ALL_BUILD_MODULES),$(if $(call is-module-prebuilt,$(__mod)),$(empty),$(__mod)-cloc))
	@echo "Done all-cloc"

# Just to test clean target of all modules
.PHONY: all-clean
all-clean: $(foreach __mod,$(ALL_BUILD_MODULES) $(ALL_BUILD_MODULES_HOST),$(__mod)-clean)
	$(Q)rm -f $(AUTOCONF_MERGE_FILE)
	$(Q)rm -f $(USER_MAKEFILES_CACHE)
	$(Q)[ ! -d $(TARGET_OUT_BUILD) ] || find $(TARGET_OUT_BUILD) -depth -type d -empty -delete
	$(Q)[ ! -d $(HOST_OUT_BUILD) ] || find $(HOST_OUT_BUILD) -depth -type d -empty -delete
	$(Q)[ ! -d $(TARGET_OUT_STAGING) ] || find $(TARGET_OUT_STAGING) -depth -type d -empty -delete
	$(Q)[ ! -d $(HOST_OUT_STAGING) ] || find $(HOST_OUT_STAGING) -depth -type d -empty -delete
	@echo "Done cleaning"

# Just to test dirclean target of all modules
.PHONY: all-dirclean
all-dirclean: $(foreach __mod,$(ALL_BUILD_MODULES) $(ALL_BUILD_MODULES_HOST),$(__mod)-dirclean)
	$(Q)rm -f $(AUTOCONF_MERGE_FILE)
	$(Q)rm -f $(USER_MAKEFILES_CACHE)
	$(Q)[ ! -d $(TARGET_OUT_STAGING) ] || find $(TARGET_OUT_STAGING) -depth -type d -empty -delete
	$(Q)[ ! -d $(HOST_OUT_STAGING) ] || find $(HOST_OUT_STAGING) -depth -type d -empty -delete
	@echo "Done cleaning directories"

# Most users want a clobber when they ask for clean or dirclean
# To really do clean or dirclean for EACH module (takes some time)
# see all-clean and all-dirclean
.PHONY: clean
.PHONY: dirclean
clean: clobber
dirclean: clobber

.PHONY: clobber
clobber:
	$(Q)rm -f $(TARGET_OUT)/global.config
	@echo "Deleting build directory..."
	$(Q)rm -rf $(TARGET_OUT_BUILD)
	@echo "Deleting staging directory..."
	$(Q)rm -rf $(TARGET_OUT_STAGING)
	@echo "Deleting build-host directory..."
	$(Q)rm -rf $(HOST_OUT_BUILD)
	@echo "Deleting staging-host directory..."
	$(Q)rm -rf $(HOST_OUT_STAGING)
	@echo "Deleting doc directory..."
	$(Q)rm -rf $(TARGET_OUT)/doc
	@echo "Done deleting directories..."

# Dummy target to check internal variables
.PHONY: check
check:

# Dump internal database
include $(BUILD_SYSTEM)/dump-database.mk

# Graph of build dependencies
include $(BUILD_SYSTEM)/build-graph.mk

# Final tree generation
include $(BUILD_SYSTEM)/final.mk

# Image generation
include $(BUILD_SYSTEM)/image.mk

# Gdb helpers
include $(BUILD_SYSTEM)/gdb.mk

# Sdk helpers
include $(BUILD_SYSTEM)/sdk.mk

# Symbols helpers
include $(BUILD_SYSTEM)/symbols.mk

# Properies helpers
include $(BUILD_SYSTEM)/properties.mk

# Open Source Software packages helpers
include $(BUILD_SYSTEM)/oss-packages.mk

# Code coverage helpers
include $(BUILD_SYSTEM)/coverage.mk

# Help
include $(BUILD_SYSTEM)/help.mk

###############################################################################
#
###############################################################################

# Depends on this to be executed AFTER building all modules
# If nothing has been requested to be built, this is a no op
.PHONY: post-build
post-build: $(__modlist)
all: post-build

.PHONY: pre-final
pre-final: post-build

# Depends on this to be executed AFTER final directory has been done
# If 'final' is not given in goals, this is a no op
.PHONY: post-final
ifneq ("$(call is-targets-in-make-goals,final)","")
post-final: post-build final
else
post-final: post-build
endif

###############################################################################
## Under native linux target, copy wrapper scripts
###############################################################################

NATIVE_WRAPPER_SCRIPT :=
NATIVE_CHROOT_WRAPPER_SCRIPT :=

ifeq ("$(TARGET_OS)","linux")

ifeq ("$(TARGET_OS_FLAVOUR)","native")
  NATIVE_WRAPPER_SCRIPT := native-wrapper.sh
endif

ifeq ("$(TARGET_OS_FLAVOUR)","native-chroot")
  NATIVE_WRAPPER_SCRIPT := native-wrapper.sh
  NATIVE_CHROOT_WRAPPER_SCRIPT := native-chroot-wrapper.sh
endif

else ifeq ("$(TARGET_OS)","darwin")

ifeq ("$(TARGET_OS_FLAVOUR)","native")
  NATIVE_WRAPPER_SCRIPT := native-darwin-wrapper.sh
endif

endif

ifneq ("$(NATIVE_WRAPPER_SCRIPT)","")

$(eval $(call copy-one-file, \
	$(BUILD_SYSTEM)/scripts/$(NATIVE_WRAPPER_SCRIPT), \
	$(TARGET_OUT_STAGING)/$(NATIVE_WRAPPER_SCRIPT)))

$(ALL_BUILD_MODULES): $(TARGET_OUT_STAGING)/$(NATIVE_WRAPPER_SCRIPT)

endif

ifneq ("$(NATIVE_CHROOT_WRAPPER_SCRIPT)","")

$(eval $(call copy-one-file, \
	$(BUILD_SYSTEM)/scripts/$(NATIVE_CHROOT_WRAPPER_SCRIPT), \
	$(TARGET_OUT_STAGING)/$(NATIVE_CHROOT_WRAPPER_SCRIPT)))

$(ALL_BUILD_MODULES): $(TARGET_OUT_STAGING)/$(NATIVE_CHROOT_WRAPPER_SCRIPT)

# Add a dummy file to warn user that the staging directory is not the one to
# use for native chroot, it shall be the final directory.
$(ALL_BUILD_MODULES): $(TARGET_OUT_STAGING)/THIS_IS_NOT_THE_DIRECTORY_FOR_NATIVE_CHROOT
$(TARGET_OUT_STAGING)/THIS_IS_NOT_THE_DIRECTORY_FOR_NATIVE_CHROOT:
	@mkdir -p $(dir $@)
	@echo "Please use the 'final' directory to launch native chroot" > $@

endif

$(info Processing rules...)
