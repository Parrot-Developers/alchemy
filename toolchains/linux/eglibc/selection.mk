###############################################################################
## @file toolchains/linux/eglibc/selection.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Setup toolchain variables.
###############################################################################

ifndef TARGET_CROSS
  ifeq ("$(TARGET_ARCH)","arm")
    ifeq ("$(TARGET_CPU)","p6")
      TARGET_CROSS := /opt/arm-2009q1/bin/arm-none-linux-gnueabi-
    else ifeq ("$(TARGET_CPU)","p6i")
      TARGET_CROSS := /opt/arm-2009q1/bin/arm-none-linux-gnueabi-
    else ifeq ("$(TARGET_CPU)","o3")
      TARGET_CROSS := /opt/arm-2017.02-octopus3/bin/arm-octopus3-linux-gnueabi-
    else
      TARGET_CROSS := /opt/arm-2012.03/bin/arm-none-linux-gnueabi-
    endif
  else ifeq ("$(TARGET_ARCH)","aarch64")
      TARGET_CROSS := /opt/arm-2016.02-aarch64-linaro/bin/aarch64-linux-gnu-
  endif
endif
