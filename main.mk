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
ALCHEMY_VERSION_MINOR := 2
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
USE_AUTOTOOLS_CACHE ?= 0
USE_AUTO_LIB_PREFIX ?= 0
USE_LINK_MAP_FILE ?= 1

# The host module feature might break temporatily some atom/mk, add a flag
# so it can be checked
ALCHEMY_SUPPORT_HOST_MODULE := 1

# Quiet command if V is 0
ifeq ("$(V)","0")
  Q := @
  MAKEFLAGS += --no-print-directory
else
  Q :=
endif

# This is the default target.  It must be the first declared target.
all:

# To avoid use of undefined variable, force our default goal
MAKECMDGOALS ?= all

# Used to force goals to build.
.PHONY: .FORCE
.FORCE:

###############################################################################
## The following 2 macros can NOT be put in defs.mk as it will be included
## only after.
###############################################################################

# Figure out where we are
# It returns the full path without trailing '/'
my-dir = $(abspath $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST)))))

###############################################################################
## Env system setup.
###############################################################################

# Directories (full and real path)
ALCHEMY_WORKSPACE_DIR ?= $(shell pwd)
TOP_DIR := $(realpath $(ALCHEMY_WORKSPACE_DIR))

# Import target product from env
ifdef ALCHEMY_TARGET_PRODUCT
  TARGET_PRODUCT := $(ALCHEMY_TARGET_PRODUCT)
endif

# Import target product variant from env
ifdef ALCHEMY_TARGET_PRODUCT_VARIANT
  TARGET_PRODUCT_VARIANT := $(ALCHEMY_TARGET_PRODUCT_VARIANT)
endif

# Import target config dir from env
ifdef ALCHEMY_TARGET_CONFIG_DIR
  TARGET_CONFIG_DIR := $(ALCHEMY_TARGET_CONFIG_DIR)
endif

# Import target out dir from env
ifdef ALCHEMY_TARGET_OUT
  TARGET_OUT := $(ALCHEMY_TARGET_OUT)
endif

# Import skel dis from env
ifdef ALCHEMY_TARGET_SKEL_DIRS
  TARGET_SKEL_DIRS := $(ALCHEMY_TARGET_SKEL_DIRS)
endif

# Import scan add dirs from env
ifdef ALCHEMY_TARGET_SCAN_ADD_DIRS
  TARGET_SCAN_ADD_DIRS := $(ALCHEMY_TARGET_SCAN_ADD_DIRS)
endif

# Import scan prune dirs from env
ifdef ALCHEMY_TARGET_SCAN_PRUNE_DIRS
  TARGET_SCAN_PRUNE_DIRS := $(ALCHEMY_TARGET_SCAN_PRUNE_DIRS)
endif

# Import sdk dirs from env
ifdef ALCHEMY_TARGET_SDK_DIRS
  TARGET_SDK_DIRS := $(ALCHEMY_TARGET_SDK_DIRS)
endif

# Import use colors from env
ifdef ALCHEMY_USE_COLORS
  USE_COLORS := $(ALCHEMY_USE_COLORS)
endif

###############################################################################
## Build system setup.
###############################################################################

BUILD_SYSTEM := $(call my-dir)

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

# Include product env file
ifdef TARGET_CONFIG_DIR
-include $(TARGET_CONFIG_DIR)/product.mk
endif

# Setup macros definitions
include $(BUILD_SYSTEM)/variables.mk
include $(BUILD_SYSTEM)/defs.mk

# Make sure all TARGET_xxx variables that we received does not have trailing
# spaces or end of line
$(foreach __var,$(vars-TARGET), \
	$(if $(call is-var-defined,TARGET_$(__var)), \
		$(eval TARGET_$(__var) := $(strip $(TARGET_$(__var)))) \
	) \
)

# If a sdk has a setup.mk file, include it
TARGET_SDK_DIRS ?=
$(foreach __dir,$(TARGET_SDK_DIRS), \
	$(eval -include $(__dir)/setup.mk) \
)

# Remember all TARGET_XXX variables from external setup
# FIXME: using := causes trouble if one of the sdk setup file has done a +=
# on a TARGET variable and used a not yet defined variable
#
# For example:
# TARGET_GLOBAL_LDFLAGS += \
#     -L$(TARGET_OUT_STAGING)/usr/lib/arm-linux-gnueabihf/tegra
# TARGET_OUT_STAGING is NOT yet defined, it will be below
#
# It works because the var will be recursive and not immediate
# So we use macro-copy and after full setup value will be correct.
$(foreach __var,$(vars-TARGET_SETUP), \
	$(if $(call is-var-defined,TARGET_$(__var)), \
		$(call macro-copy,TARGET_SETUP_$(__var),TARGET_$(__var)) \
	) \
)

# Setup configuration
include $(BUILD_SYSTEM)/setup.mk

###############################################################################
# Optimizations for some goals.
###############################################################################

# Define some target class
__clobber-targets := clobber clean dirclean
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
## Setup part2 (may use optimization flags from above).
###############################################################################

# Setup internal build definitions
include $(BUILD_SYSTEM)/binary-setup.mk

# Setup autotools definitions (shall be after inclusion of defs.mk)
include $(BUILD_SYSTEM)/autotools-setup.mk

# Setup CMake definitions
include $(BUILD_SYSTEM)/cmake-setup.mk

# Setup QMake definitions
include $(BUILD_SYSTEM)/qmake-setup.mk

# Setup warnings flags
include $(BUILD_SYSTEM)/warnings.mk

# Setup configuration definitions
include $(BUILD_SYSTEM)/config-defs.mk

# User specific debug setup makefile
debug-setup-makefile := Alchemy-debug-setup.mk
ifneq ("$(wildcard $(TOP_DIR)/$(debug-setup-makefile))","")
  ifneq ("$(V)","0")
    $(info Including debug setup makefile)
  endif
  include $(TOP_DIR)/$(debug-setup-makefile)
endif

# Names of makefiles that can be included by user Makefiles
CLEAR_VARS := $(BUILD_SYSTEM)/clearvars.mk
BUILD_STATIC_LIBRARY := $(BUILD_SYSTEM)/static.mk
BUILD_SHARED_LIBRARY := $(BUILD_SYSTEM)/shared.mk
BUILD_LIBRARY := $(BUILD_SYSTEM)/library.mk
BUILD_EXECUTABLE := $(BUILD_SYSTEM)/executable.mk
BUILD_AUTOTOOLS := $(BUILD_SYSTEM)/autotools.mk
BUILD_CMAKE := $(BUILD_SYSTEM)/cmake.mk
BUILD_QMAKE := $(BUILD_SYSTEM)/qmake.mk
BUILD_PYTHON_EXTENSION := $(BUILD_SYSTEM)/python-ext.mk
BUILD_CUSTOM := $(BUILD_SYSTEM)/custom.mk
BUILD_META_PACKAGE := $(BUILD_SYSTEM)/meta.mk
BUILD_LINUX := $(BUILD_SYSTEM)/linuxkernel.mk
BUILD_PREBUILT := $(BUILD_SYSTEM)/prebuilt.mk
BUILD_LINUX_MODULE := $(BUILD_SYSTEM)/linuxkernelmodule.mk
BUILD_GI_TYPELIB := $(BUILD_SYSTEM)/gobject-introspection.mk

# Shall be defined before including user makefiles
AUTOCONF_MERGE_FILE := $(TARGET_OUT_BUILD)/autoconf-merge.h

###############################################################################
## Makefile scan and includes.
###############################################################################

# Makefile with the list of all makefiles available and include them
USER_MAKEFILE_NAME := atom.mk
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

# Summary of what we found
display-user-makefiles-summary = \
	$(if $(call strneq,$(V),0), \
		$(foreach __f,$(USER_MAKEFILES),$(info $(__f))) \
	) \
	$(info Found $(words $(USER_MAKEFILES)) makefiles)

# Create a file that will contain all user makefiles available
# Make sure that atom.mk from sdk are included first so they can be overriden
# Put target/os specific packages AFTER sdk for same reason
create-user-makefiles-cache = \
	rm -f $(USER_MAKEFILES_CACHE); \
	mkdir -p $(dir $(USER_MAKEFILES_CACHE)); \
	touch $(USER_MAKEFILES_CACHE); \
	( \
		files="$(addsuffix /$(USER_MAKEFILE_NAME),$(TARGET_SDK_DIRS)) \
			$(BUILD_SYSTEM)/toolchains/toolchains-packages.mk \
		"; \
		for f in $$files `$(find-cmd)`; do \
			echo "USER_MAKEFILES += $$f"; \
			echo "\$$(call user-makefile-before-include,$$f)"; \
			echo "include $$f"; \
			echo "\$$(call user-makefile-after-include,$$f)"; \
		done \
	) >> $(USER_MAKEFILES_CACHE);

# Determine if we need to re-create the cache
do-create-cache := 0
ifeq ("$(USE_SCAN_CACHE)","0")
  do-create-cache := 1
else ifneq ("$(call is-targets-in-make-goals,scan)","")
  do-create-cache := 1
else
  $(warning Using scan cache, some atom.mk might be missing...)
endif

ifneq ("$(do-create-cache)","0")

# Force regeneration of cache and include scanned files
# Assignation to dummy variable is to ignore any output of shell command
dummy := $(shell $(create-user-makefiles-cache))
include $(USER_MAKEFILES_CACHE)
$(call display-user-makefiles-summary)

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
  $(call display-user-makefiles-summary)
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
ifeq ("$(CONFIG_GLOBAL_FILE_AVAILABLE)","0")
$(foreach __mod,$(ALL_BUILD_MODULES), \
	$(foreach __lib,$(call module-get-all-depends,$(__mod)), \
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
					$(call module-get-all-depends,$(__mod)) \
				) \
			) \
		) \
	) \
)

ifneq ("$(V)","0")
  $(info Generating rules: start)
endif

# Determine the list of modules to really include
# If a module is specified in goals, only include this one and its dependencies.
# If 'all' or 'check' is also given do not do the filter
# For meta packages, also get config dependencies (for build/clean shortcuts)
__modlist := $(empty)
ifeq ("$(call is-targets-in-make-goals,all check)","")
$(foreach __mod,$(ALL_BUILD_MODULES) $(ALL_BUILD_MODULES_HOST), \
	$(if $(call is-module-in-make-goals,$(__mod)), \
		$(eval __modlist += $(__mod) $(call module-get-all-depends,$(__mod))) \
		$(if $(call is-module-meta-package,$(__mod)), \
			$(foreach __mod2,$(call module-get-config-depends,$(__mod)), \
				$(eval __modlist += $(__mod2) $(call module-get-all-depends,$(__mod2))) \
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
	$(eval include $(BUILD_SYSTEM)/module.mk) \
)

ifneq ("$(V)","0")
  $(info Generating rules: done)
endif

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
.PHONY: _clean
_clean: $(foreach __mod,$(ALL_BUILD_MODULES) $(ALL_BUILD_MODULES_HOST),$(__mod)-clean)
	$(Q)rm -f $(AUTOCONF_MERGE_FILE)
	$(Q)rm -f $(USER_MAKEFILES_CACHE)
	$(Q)[ ! -d $(TARGET_OUT_STAGING) ] || find $(TARGET_OUT_STAGING) -depth -type d -empty -delete
	$(Q)[ ! -d $(HOST_OUT_STAGING) ] || find $(HOST_OUT_STAGING) -depth -type d -empty -delete
	@echo "Done cleaning"

# Just to test dirclean target of all modules
.PHONY: _dirclean
_dirclean: $(foreach __mod,$(ALL_BUILD_MODULES) $(ALL_BUILD_MODULES_HOST),$(__mod)-dirclean)
	$(Q)rm -f $(AUTOCONF_MERGE_FILE)
	$(Q)rm -f $(USER_MAKEFILES_CACHE)
	$(Q)[ ! -d $(TARGET_OUT_STAGING) ] || find $(TARGET_OUT_STAGING) -depth -type d -empty -delete
	$(Q)[ ! -d $(HOST_OUT_STAGING) ] || find $(HOST_OUT_STAGING) -depth -type d -empty -delete
	@echo "Done cleaning directories"

# Most users want a clobber when they ask for clean or dirclean
# To really do clean or dirclean for EACH module (takes some time)
# see _clean and _dirclean
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
