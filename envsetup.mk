###############################################################################
## @file envsetup.mk
## @author F. Ferrand
## @date 2015/09/20
###############################################################################

# This script is designed to allow being included from other makefile:
# e.g. to wrap Alchemy but still let it handle architecture selection and path
# mapping.

# As a consequence, we need to redefine my-dir and BUILD_SYSTEM, which are
# normally defined by Alchemy.
my-dir = $(abspath $(patsubst %/,%,$(dir $(lastword $(MAKEFILE_LIST)))))
BUILD_SYSTEM := $(call my-dir)

# Target setup
include $(BUILD_SYSTEM)/target-setup.mk

# Get access to variable contents
.PHONY: var-%
var-%:
	@echo $*=$($*)
