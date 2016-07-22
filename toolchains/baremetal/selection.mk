###############################################################################
## @file toolchains/baremetal/selection.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Setup toolchain variables.
###############################################################################

ifndef TARGET_CROSS
  export PATH := /opt/arm-2014q4-none-linaro/bin:$(PATH)
  TARGET_CROSS := /opt/arm-2014q4-none-linaro/bin/arm-none-eabi-
endif
