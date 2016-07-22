###############################################################################
## @file clearvars.mk
## @author Y.M. Morgan
## @date 2011/05/14
##
## Clear out values of all variables used by rule templates.
###############################################################################

# Do NOT clear LOCAL_PATH, it is set BEFORE including this makefile

$(call clear-vars, $(filter-out LOCAL_PATH,$(vars-LOCAL:%=LOCAL_%)))
$(call clear-vars, $(filter-out LOCAL_PATH,$(macros-LOCAL:%=LOCAL_%)))
$(call clear-vars, $(filter-out LOCAL_PATH,$(compat-vars-LOCAL:%=LOCAL_%)))

# Trim MAKEFILE_LIST so that $(call my-dir) doesn't need to
# iterate over thousands of entries every time.
# Leave the current makefile to make sure we don't break anything
# that expects to be able to find the name of the current makefile.
MAKEFILE_LIST := $(lastword $(MAKEFILE_LIST))

# This will be cleared after module is added and checked before adding it
__clear-vars-called := 1
