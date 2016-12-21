###############################################################################
## @file toolchains/linux/musl/selection.mk
## @author Y.M. Morgan
## @author J. Perchet
## @date 2016/08/01
##
## Setup toolchain variables.
###############################################################################

ifndef TARGET_CROSS
  ifeq ("$(TARGET_CPU)","o3")
    TARGET_CROSS := /opt/arm-2015.10-musl-ct-ng/bin/arm-none-linux-musleabi-
  endif
endif
