###############################################################################
## @file toolchains/linux/selection.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Setup toolchain variables.
###############################################################################

ifneq ("$(TARGET_LIBC)","")
  -include $(BUILD_SYSTEM)/toolchains/$(TARGET_OS)/$(TARGET_LIBC)/selection.mk
endif

# TODO: move this in autotools setup
# Machine targetted by toolchain to be used by autotools
# Use a name that will force autotools to believe we are cross-compiling
# Do nothing for non chroot native build with TARGET_ARCH = HOST_ARCH
ifeq ("$(TARGET_OS_FLAVOUR)-$(TARGET_ARCH)","native-$(HOST_ARCH)")
  # Leave GNU_TARGET_NAME undefined
else ifeq ("$(subst -chroot,,$(TARGET_OS_FLAVOUR))","native")
  # Native with foreign architecture or native chroot
  ifeq ("$(TARGET_ARCH)","x64")
    GNU_TARGET_NAME := x86_64-none-linux-gnu
  else ifeq ("$(TARGET_ARCH)","x86")
    GNU_TARGET_NAME := i686-none-linux-gnu
  endif
else
  # Not a native flavour
  ifeq ("$(TARGET_ARCH)","x64")
    GNU_TARGET_NAME := x86_64-none-linux-gnu
  else ifeq ("$(TARGET_ARCH)","x86")
    GNU_TARGET_NAME := i686-none-linux-gnu
  else ifeq ("$(TARGET_ARCH)-$(TARGET_LIBC)","arm-musl")
     # A lot of autotools are not musl ready. Lying allows to reach a much
      # better interoperability.
    GNU_TARGET_NAME := arm-none-linux-gnueabi
  endif
endif
