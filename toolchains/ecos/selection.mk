###############################################################################
## @file toolchains/ecos/selection.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Setup toolchain variables.
###############################################################################

ifndef TARGET_CROSS
  export PATH := /usr/local/gnutools-20080328/bin:$(PATH)
  TARGET_CROSS := /usr/local/gnutools-20080328/bin/arm-elf-
endif
