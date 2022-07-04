###############################################################################
## @file toolchains/setup.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Setup variables for toolchain.
###############################################################################

# Select toolchain and setup flags.
include $(BUILD_SYSTEM)/toolchains/selection.mk
include $(BUILD_SYSTEM)/toolchains/flags.mk
include $(BUILD_SYSTEM)/toolchains/warnings.mk

# Machine targetted by toolchain to be used by autotools and libc installation
ifndef TARGET_TOOLCHAIN_TRIPLET
  __toolchain_triplet_cmd := $(TARGET_CC) $(TARGET_GLOBAL_CFLAGS)
  ifeq ("$(TARGET_CC_FLAVOUR)","clang")
    ifneq ("$(TARGET_CROSS)","")
      # clang for cross compilation with gcc for system include/libs
      __toolchain_triplet_cmd := $(TARGET_CROSS)gcc $(TARGET_GLOBAL_CFLAGS)
    endif
  endif
  # Ignore line with error message indicating LD_PRELOAD issues
  TARGET_TOOLCHAIN_TRIPLET := $(shell $(__toolchain_triplet_cmd) -print-multiarch 2>&1 | grep -v LD_PRELOAD)
  ifeq ("$(TARGET_TOOLCHAIN_TRIPLET)","")
    TARGET_TOOLCHAIN_TRIPLET := $(shell $(__toolchain_triplet_cmd) -dumpmachine)
  else ifneq ("$(findstring -print-multiarch,$(TARGET_TOOLCHAIN_TRIPLET))","")
    # compiler does not support '-print-multiarch' option
    TARGET_TOOLCHAIN_TRIPLET := $(shell $(__toolchain_triplet_cmd) -dumpmachine)
  endif
  # Catch error in compiler invocation
  ifneq ("$(findstring error,$(TARGET_TOOLCHAIN_TRIPLET))","")
    $(error Unable to determine TARGET_TOOLCHAIN_TRIPLET: $(TARGET_TOOLCHAIN_TRIPLET)))
  endif
endif

ifeq ("$(TARGET_TOOLCHAIN_TRIPLET)","")
  $(error Unable to determine TARGET_TOOLCHAIN_TRIPLET))
endif

# Clang uses gcc toochain(libc&binutils) to cross-compile
# The sysroot is the top level one (without subarch like thumb2 for arm)
# Avoid putting a space between option and argument so that our libtool patch works
ifeq ("$(TARGET_OS)","linux")
ifneq ("$(TARGET_CROSS)","")
__toolchain_sysroot := $(shell $(TARGET_CROSS)gcc \
	$(TARGET_GLOBAL_CFLAGS) \
	$(TARGET_GLOBAL_CFLAGS_gcc) \
	-print-sysroot)
__toolchain_root := $(shell PARAM=$(TARGET_CROSS)gcc; echo $${PARAM%/bin*})
ifeq ("$(__toolchain_sysroot)","")
ifeq ("$(TARGET_OS_FLAVOUR)","android")
__toolchain_sysroot := $(__toolchain_root)/sysroot
endif
endif
__toolchain_cflags_clang := \
	--target=$(TARGET_TOOLCHAIN_TRIPLET) \
	--sysroot=$(__toolchain_sysroot) \
	--gcc-toolchain=$(__toolchain_root) \
	-B$(__toolchain_root)/bin
TARGET_GLOBAL_CFLAGS_clang += $(__toolchain_cflags_clang) #-fno-integrated-as
TARGET_GLOBAL_LDFLAGS_clang += $(__toolchain_cflags_clang)
endif
endif

# Get libc/gdbserver to copy
# We use cflags as well as arm/thumb mode to select correct variant
TARGET_TOOLCHAIN_SYSROOT ?=
TOOLCHAIN_LIBC ?=
TOOLCHAIN_GDBSERVER ?=
ifeq ("$(TARGET_OS)","linux")
  ifeq ("$(TARGET_OS_FLAVOUR)","native-chroot")
    __need_sysroot := 1
  else ifeq ("$(TARGET_LIBC)","eglibc")
    __need_sysroot := 1
  else ifeq ("$(TARGET_LIBC)","musl")
    __need_sysroot := 1
  else
    __need_sysroot := 0
  endif
  ifeq ("$(__need_sysroot)","1")
    __toolchain-sysroot-flags := $(TARGET_GLOBAL_CFLAGS)
    ifeq ("$(TARGET_ARCH)","arm")
      __toolchain-sysroot-flags += $(TARGET_GLOBAL_CFLAGS_$(TARGET_DEFAULT_ARM_MODE))
    endif
    ifeq ("$(TARGET_OS_FLAVOUR)","yocto")
      __toolchain-sysroot-flags += $(call rest,$(TARGET_CC))
    endif
    TARGET_TOOLCHAIN_SYSROOT := $(shell $(TARGET_CROSS)gcc $(__toolchain-sysroot-flags) -print-sysroot)
    ifeq ("$(wildcard $(TARGET_TOOLCHAIN_SYSROOT))","")
        TOOLCHAIN_LIBC := /
    else
      TOOLCHAIN_LIBC := $(TARGET_TOOLCHAIN_SYSROOT)
    endif
    TOOLCHAIN_GDBSERVER := $(firstword                                  \
                             $(wildcard                                 \
                               $(addprefix $(TARGET_TOOLCHAIN_SYSROOT), \
                                 $(addsuffix /gdbserver,                \
                                   /usr/bin                             \
                                   /../bin                              \
                                   /../../bin                           \
                                   /../debug-root/usr/bin               \
                                   /../host_bin                         \
                                  ))))
  endif
endif

###############################################################################
## Update global flags with flavour ones.
###############################################################################

HOST_GLOBAL_CFLAGS += $(HOST_GLOBAL_CFLAGS_$(HOST_CC_FLAVOUR))
HOST_GLOBAL_CXXFLAGS += $(HOST_GLOBAL_CXXFLAGS_$(HOST_CC_FLAVOUR))
HOST_GLOBAL_LDFLAGS += $(HOST_GLOBAL_LDFLAGS_$(HOST_CC_FLAVOUR))

TARGET_GLOBAL_CFLAGS += $(TARGET_GLOBAL_CFLAGS_$(TARGET_CC_FLAVOUR))
TARGET_GLOBAL_CXXFLAGS += $(TARGET_GLOBAL_CXXFLAGS_$(TARGET_CC_FLAVOUR))
TARGET_GLOBAL_LDFLAGS += $(TARGET_GLOBAL_LDFLAGS_$(TARGET_CC_FLAVOUR))

###############################################################################
## Update host include/lib directories.
###############################################################################

# Make sure that staging dir are found first in case we want to override something
# TODO add SDK dirs
__extra-host-c-includes := $(strip \
	$(foreach __dir,$(HOST_OUT_STAGING), \
		$(__dir)/$(HOST_ROOT_DESTDIR)/include \
	))
HOST_GLOBAL_C_INCLUDES := $(__extra-host-c-includes) $(HOST_GLOBAL_C_INCLUDES)

# Add staging/sdk dirs to linker
# To make sure linker does not hardcode path to libs, set rpath-link.
# TODO add SDK dirs
# TODO should not be needed because we don't support dynamic linking in host.
__extra-host-ldflags := $(strip \
	$(foreach __dir,$(HOST_OUT_STAGING), \
		-L$(__dir)/lib \
		-L$(__dir)/$(HOST_DEFAULT_LIB_DESTDIR) \
	))
ifneq ("$(HOST_OS)","darwin")
__extra-host-ldflags += $(strip \
	$(foreach __dir,$(HOST_OUT_STAGING), \
		-Wl,-rpath-link=$(__dir)/lib \
		-Wl,-rpath-link=$(__dir)/$(HOST_DEFAULT_LIB_DESTDIR) \
	))
endif

HOST_GLOBAL_LDFLAGS += $(__extra-host-ldflags)

###############################################################################
## Update target include/lib directories.
###############################################################################

# Make sure include path in staging directory exists
$(shell mkdir -p $(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR)/include)
$(shell mkdir -p $(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR)/include/$(TARGET_TOOLCHAIN_TRIPLET))

# Make sure that staging dir are found first in case we want to override something
__extra-target-c-includes := $(strip \
	$(foreach __dir,$(TARGET_OUT_STAGING) $(TARGET_SDK_DIRS), \
		$(wildcard \
			$(__dir)/$(TARGET_ROOT_DESTDIR)/include/$(TARGET_TOOLCHAIN_TRIPLET) \
			$(__dir)/$(TARGET_ROOT_DESTDIR)/include \
		) \
	))
TARGET_GLOBAL_C_INCLUDES := $(__extra-target-c-includes) $(TARGET_GLOBAL_C_INCLUDES)

# Add staging/sdk dirs to linker
# To make sure linker does not hardcode path to libs, set rpath-link
__extra-target-ldflags-dirs := \
	lib/$(TARGET_TOOLCHAIN_TRIPLET) \
	lib \
	$(TARGET_DEFAULT_LIB_DESTDIR)/$(TARGET_TOOLCHAIN_TRIPLET) \
	$(TARGET_DEFAULT_LIB_DESTDIR) \
	$(TARGET_LDCONFIG_DIRS)
__extra-target-ldflags := $(strip \
	$(foreach __dir,$(TARGET_OUT_STAGING) $(TARGET_SDK_DIRS), \
		$(foreach __dir2,$(__extra-target-ldflags-dirs), \
			-L$(__dir)/$(__dir2) \
		) \
	))
ifneq ("$(TARGET_OS)","darwin")
__extra-target-ldflags += $(strip \
	$(foreach __dir,$(TARGET_OUT_STAGING) $(TARGET_SDK_DIRS), \
		$(foreach __dir2,$(__extra-target-ldflags-dirs), \
			-Wl,-rpath-link=$(__dir)/$(__dir2) \
		) \
	))
endif

TARGET_GLOBAL_LDFLAGS += $(__extra-target-ldflags)

###############################################################################
# Retrieve the path to the target's loader
###############################################################################

ifeq ("$(TARGET_OS)","linux")
ifneq ("$(TARGET_OS_FLAVOUR)","android")
TARGET_LOADER := $(strip $(shell \
	tmpfile=$$(mktemp -t tmp.XXXXXXXXXX); \
	echo 'int main(){return 0;}' | \
	$(TARGET_CC) $(TARGET_GLOBAL_CFLAGS) \
		-o $${tmpfile} -xc -; \
	readelf -l $${tmpfile} | \
	grep 'interpreter:' | \
	sed -e 's/.*: \(.*\)\]/\1/g'; \
	rm -f $${tmpfile}; \
))
endif
endif
TARGET_LOADER ?=

###############################################################################
## ccache setup.
###############################################################################

# To be able to use ccache with pre-compiled headers, some environment
# variables are required
CCACHE :=
ifeq ("$(USE_CCACHE)","1")
  ifneq ("$(shell which ccache 2>/dev/null)","")
    export CCACHE_SLOPPINESS := time_macros
    CCACHE := ccache
    TARGET_GLOBAL_CFLAGS += -fpch-preprocess
    HOST_GLOBAL_CFLAGS += -fpch-preprocess
  endif
endif
