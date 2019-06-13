###############################################################################
## @file toolchains/windows/selection.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Setup toolchain variables.
###############################################################################

ifndef TARGET_CROSS
  ifneq ("$(HOST_OS)","windows")
    ifeq ("$(TARGET_LIBC)","mingw")
      ifeq ("$(TARGET_ARCH)","x86")
        TARGET_CROSS := i686-w64-mingw32-
      else ifeq ("$(TARGET_ARCH)","x64")
        TARGET_CROSS := x86_64-w64-mingw32-
      endif
    endif
  endif
endif
