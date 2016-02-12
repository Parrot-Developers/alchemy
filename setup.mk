###############################################################################
## @file setup.mk
## @author Y.M. Morgan
## @date 2011/05/14
###############################################################################

###############################################################################
## Check some stuff first.
###############################################################################

# Make sure that there are no spaces in the absolute path; the build system
# can't deal with them.
ifneq ("$(words $(shell pwd))","1")
$(error Top directory contains space characters)
endif

###############################################################################
## Target configuration.

include $(BUILD_SYSTEM)/envsetup.mk

TARGET_SKEL_DIRS ?=
TARGET_NOSTRIP_FINAL ?= 0

# Force compilation of all modules as static (disable shared libraries)
TARGET_FORCE_STATIC ?= 0

# Force using static libraries instead of shared for module that specifies they support it
ifeq ("$(TARGET_FORCE_STATIC)","1")
  TARGET_PBUILD_FORCE_STATIC := 1
else
  TARGET_PBUILD_FORCE_STATIC ?= 0
endif

# Register list of tags used by a module. It can be retrieved at run time with
# pal function 'pal_lib_desc_get_table_entry'
TARGET_PBUILD_HOOK_USE_DESCRIBE ?= 0

# Set to 1 to follow symbolic links during scan
TARGET_SCAN_FOLLOW_LINKS ?= 0

# Directories to use as sdk
TARGET_SDK_DIRS ?=

# Default : do NOT force external checks of module that have sub-makefiles
# (autotools, linux kernel...)
# make F=1 enable force checking
TARGET_FORCE_EXTERNAL_CHECKS ?= 0
ifneq ("$(F)","0")
  TARGET_FORCE_EXTERNAL_CHECKS := 1
endif

# Global prerequisites (shall be used only by os makefile)
TARGET_GLOBAL_PREREQUISITES :=

# Add a section in executable/shared library with dependencies used
TARGET_ADD_DEPENDS_SECTION ?= 0
TARGET_DEPENDS_SECTION_NAME ?= .alchemy.depends
ifneq ("$(TARGET_ADD_DEPENDS_SECTION)","0")
ifeq ("$(USE_GIT_REV)","0")
  $(warning TARGET_ADD_DEPENDS_SECTION requires USE_GIT_REV, disabling ...)
  TARGET_ADD_DEPENDS_SECTION := 0
endif
endif

# Add a section in executable/shared library with a sha1 of loadable sections
# of binary
TARGET_ADD_BUILDID_SECTION ?= 0
TARGET_BUILDID_SECTION_NAME ?= .alchemy.build-id

# List of filenames to filter during strip (no wildcard allowed here because
# module.mk will also look in this list to filter, not only final.mk)
TARGET_STRIP_FILTER :=

# List of files with permissions to be applied
# See documentation for format of file.
TARGET_PERMISSIONS_FILES ?=

# Set to 1 if the result of the compilation will be executed in a chroot
# environment. Used by some modules to adapt their configuration
TARGET_CHROOT ?= 0

# File containing path mapping to be used when generating image (plf for example)
# Used by chroot target that are not flashed in the same root as the build.
# See documentation for format of file.
TARGET_IMAGE_PATH_MAP_FILE ?=

# List of target wise build properties to be put in build.prop file
TARGET_BUILD_PROPERTIES ?=

# Include gdbserver (GPLv3) or not in target
TARGET_INCLUDE_GDBSERVER ?= 1

# Include TZData or not in the target
TARGET_INCLUDE_TZDATA ?= 0

# Include Gconv or not on the target
TARGET_INCLUDE_GCONV ?= 0

# Enable c++ exceptions
TARGET_USE_CXX_EXCEPTIONS ?= 1

# Link cpio image inside the kernel.
TARGET_LINUX_LINK_CPIO_IMAGE ?= 0

# Generate a Uboot image of linux
TARGET_LINUX_GENERATE_UIMAGE ?= 0

# Copy device tree files to the boot directory
TARGET_LINUX_DEVICE_TREE_NAMES ?=

# TODO: remove compatibility with old name in future version
ifdef TARGET_LINUX_DEVICE_TREE
  TARGET_LINUX_DEVICE_TREE_NAMES += $(TARGET_LINUX_DEVICE_TREE)
endif

# Target image format (tar, cpio, ext2, ext3, ext4, plf)
# It can optionaly be suffixed with .gz or .bz2 to compress the image
TARGET_IMAGE_FORMAT ?= tar.gz

# Target image generation options (not used for plf images)
# --size : size ((in bytes, suffixes K,M,G allowed)) of the image file
# --sparse : generate a sparse image
TARGET_IMAGE_OPTIONS ?=

# To simplify tests for arm architecture
TARGET_ARCH_ARM := 0
ifeq ("$(TARGET_ARCH)","arm")
  TARGET_ARCH_ARM := 1
else ifeq ("$(TARGET_ARCH)","aarch64")
  TARGET_ARCH_ARM := 1
endif

# Customize how final tree is done (what will be filtered)
# full: nothing filtered
# firmware: filtered according to internal heuristics suitable for embedded execution
TARGET_FINAL_MODE ?= firmware

###############################################################################
## Toolchain setup.
###############################################################################
include $(BUILD_SYSTEM)/toolchains/toolchains-setup.mk

###############################################################################
## Host setup.
###############################################################################
HOST_OUT_BUILD ?= $(TARGET_OUT)/build-host
HOST_OUT_STAGING ?= $(TARGET_OUT)/staging-host

HOST_CXX ?= g++
HOST_AS ?= as
HOST_AR ?= ar
HOST_LD ?= ld
HOST_NM ?= nm
HOST_STRIP ?= strip
HOST_CPP ?= cpp
HOST_RANLIB ?= ranlib
HOST_OBJCOPY ?= objcopy
HOST_OBJDUMP ?= objdump

# Setup flags
HOST_GLOBAL_C_INCLUDES ?=
HOST_GLOBAL_ASFLAGS ?=
HOST_GLOBAL_CFLAGS ?=
HOST_GLOBAL_CXXFLAGS ?=
HOST_GLOBAL_ARFLAGS ?=
HOST_GLOBAL_LDFLAGS ?=
HOST_GLOBAL_LDFLAGS_SHARED ?=
HOST_GLOBAL_LDLIBS ?=
HOST_GLOBAL_LDLIBS_SHARED ?=
HOST_GLOBAL_PCH_FLAGS ?=

# Add some generic flags
HOST_GLOBAL_CFLAGS += -pipe -O2 -g0
HOST_GLOBAL_ARFLAGS += rcs
HOST_GLOBAL_LDFLAGS +=

# Update flags based on architecture
# 64-bit requires -fPIC to build shared libraries
ifeq ("$(HOST_ARCH)","x64")
  HOST_GLOBAL_CFLAGS += -m64 -fPIC
  HOST_GLOBAL_LDFLAGS += -m64
  HOST_GLOBAL_LDFLAGS_SHARED += -m64
else
  HOST_GLOBAL_CFLAGS += -m32
  HOST_GLOBAL_LDFLAGS += -m32
  HOST_GLOBAL_LDFLAGS_SHARED += -m32
endif

###############################################################################
## Copy content of host staging from sdks.
## Required because some modules expect to find tools in $(HOST_OUT_STAGING)
## even if it comed from a sdk.
###############################################################################

# Generate rules to copy content of host staging from a sdk
# $1 : sdk dir
# The copy will be done only when the atom.mk of the sdk is changed (which is
# normally the case when the sdk is regenerated)
# The copy will be triggered before the build (TARGET_GLOBAL_PREREQUISITES)
# If several sdk are used, copy them sequentially (__sdk-copy-host-list will
# contains previously copied sdk).
__sdk-copy-host-list :=
define __sdk-copy-host
$(TARGET_OUT_BUILD)/sdk_$(subst /,_,$1).done: $1/$(USER_MAKEFILE_NAME) $(__sdk-copy-host-list)
	@echo "Copying $1/host/ to $(HOST_OUT_STAGING)"
	@mkdir -p $$(dir $$@)
	@mkdir -p $(HOST_OUT_STAGING)
	@cp -Raf $1/host/* $(HOST_OUT_STAGING)
	@touch $$@
TARGET_GLOBAL_PREREQUISITES += $(TARGET_OUT_BUILD)/sdk_$(subst /,_,$1).done
__sdk-copy-host-list += $(TARGET_OUT_BUILD)/sdk_$(subst /,_,$1).done
endef

$(foreach __dir,$(TARGET_SDK_DIRS), \
	$(if $(wildcard $(__dir)/host), \
		$(eval $(call __sdk-copy-host,$(__dir))) \
	) \
)

###############################################################################
## Find some tools.
###############################################################################

ifeq ("$(HOST_OS)","darwin")
# Use bison from Homebrew by default on MacOS, as Xcode version is too old
BISON_HOMEBREW_PATH = /usr/local/opt/bison/bin/bison
BISON_PATH ?= $(shell if [ -e $(BISON_HOMEBREW_PATH) ]; then echo $(BISON_HOMEBREW_PATH); else which bison; fi)
else
BISON_PATH ?= $(shell which bison)
endif
# We need bison 2.5 but android force version 2.3 in the path that causes troubles
ifneq ("$(BISON_PATH)","")
  BISON_VERSION := $(shell $(BISON_PATH) --version | head -1 | perl -pe "s/.*?([0-9]+\.[0-9]+(\.[0-9]+)?(-[0-9]+)?)$$/\1/")
  ifeq ("$(call check-version,$(BISON_VERSION),2.5)","")
    BISON_PATH := /usr/bin/bison
  endif
endif

###############################################################################
## Update host flags.
###############################################################################

# Make sure that staging dir are found first in case we want to override something
# TODO add SDK dirs
__extra-host-c-includes := $(strip \
	$(foreach __dir,$(HOST_OUT_STAGING), \
		$(__dir)/usr/include \
	))
HOST_GLOBAL_C_INCLUDES := $(__extra-host-c-includes) $(HOST_GLOBAL_C_INCLUDES)

# Notify that build is performed by alchemy
HOST_GLOBAL_CFLAGS += -DALCHEMY_BUILD

# Add staging/sdk dirs to linker
# To make sure linker does not hardcode path to libs, set rpath-link.
# TODO add SDK dirs
# TODO should not be needed because we don't support dynamic linking in host.
__extra-host-ldflags := $(strip \
	$(foreach __dir,$(HOST_OUT_STAGING), \
		-L$(__dir)/lib \
		-L$(__dir)/usr/lib \
	))
ifneq ("$(HOST_OS)","darwin")
__extra-host-ldflags += $(strip \
	$(foreach __dir,$(HOST_OUT_STAGING), \
		-Wl,-rpath-link=$(__dir)/lib \
		-Wl,-rpath-link=$(__dir)/usr/lib \
	))
endif

HOST_GLOBAL_LDFLAGS += $(__extra-host-ldflags)
HOST_GLOBAL_LDFLAGS_SHARED += $(__extra-host-ldflags)

# Don't emit warning for unused driver arguments
ifeq ("$(USE_CLANG)","1")
  HOST_GLOBAL_CFLAGS += -Qunused-arguments
endif

###############################################################################
## Update target flags.
###############################################################################

# Make sure include path in staging directory exists
$(shell mkdir -p $(TARGET_OUT_STAGING)/usr/include)
$(shell mkdir -p $(TARGET_OUT_STAGING)/usr/include/$(TOOLCHAIN_TARGET_NAME))

# Make sure that staging dir are found first in case we want to override something
__extra-target-c-includes := $(strip \
	$(foreach __dir,$(TARGET_OUT_STAGING) $(TARGET_SDK_DIRS), \
		$(wildcard \
			$(__dir)/usr/include \
			$(__dir)/usr/include/$(TOOLCHAIN_TARGET_NAME) \
		) \
	))
TARGET_GLOBAL_C_INCLUDES := $(__extra-target-c-includes) $(TARGET_GLOBAL_C_INCLUDES)

# So that everyone knowns we are building with alchemy.
TARGET_GLOBAL_CFLAGS += -DALCHEMY_BUILD

# TODO : is it really the place and where to do it ?
ifeq ("$(findstring -D__STDC_LIMIT_MACROS,$(TARGET_GLOBAL_CXXFLAGS))","")
  TARGET_GLOBAL_CXXFLAGS += -D__STDC_LIMIT_MACROS
endif

# Add staging/sdk dirs to linker
# To make sure linker does not hardcode path to libs, set rpath-link
__extra-target-ldflags-dirs := \
	lib \
	usr/lib \
	lib/$(TOOLCHAIN_TARGET_NAME) \
	usr/lib/$(TOOLCHAIN_TARGET_NAME) \
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
TARGET_GLOBAL_LDFLAGS_SHARED += $(__extra-target-ldflags)

# Make sure the architecture specific flags is defined
# For arm/thumb it is done in toolchain setup
TARGET_GLOBAL_CFLAGS_$(TARGET_ARCH) ?=

# Don't emit warning for unused driver arguments
ifeq ("$(USE_CLANG)","1")
  TARGET_GLOBAL_CFLAGS += -Qunused-arguments
endif

# TODO : get this based on real version of valac and glib used.
TARGET_GLOBAL_VALAFLAGS += \
	--vapidir=$(HOST_OUT_STAGING)/usr/share/vala-0.20/vapi \
	$(foreach __dir,$(TARGET_OUT_STAGING) $(TARGET_SDK_DIRS), \
		--vapidir=$(__dir)/usr/share/vala/vapi \
	) \
	--target-glib=2.36

###############################################################################
## ccache setup.
###############################################################################

# To be able to use ccache with pre-compiled headers, some environment
# variables are required
CCACHE :=
ifeq ("$(USE_CCACHE)","1")
  ifneq ("$(shell which ccache)","")
    export CCACHE_SLOPPINESS := time_macros
    CCACHE := ccache
    TARGET_GLOBAL_CFLAGS += -fpch-preprocess
    HOST_GLOBAL_CFLAGS += -fpch-preprocess
  endif
endif

###############################################################################
## Default rules of makefile add TARGET_ARCH in CFLAGS.
## As it is not the way we use it, prevent export of this variable
###############################################################################
# Unexport does not work when TARGET_ARCH is set on command line, force clearing it
MAKEOVERRIDES := $(filter-out TARGET_ARCH=%,$(MAKEOVERRIDES))
unexport TARGET_ARCH

###############################################################################
## gobject-introspection setup.
###############################################################################
HOST_XDG_DATA_DIRS := $(HOST_OUT_STAGING)/usr/share
TARGET_XDG_DATA_DIRS := $(TARGET_OUT_STAGING)/usr/share
