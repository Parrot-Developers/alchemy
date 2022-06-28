###############################################################################
## @file target-setup.mk
## @author Y.M. Morgan
## @date 2016/03/08
###############################################################################

###############################################################################
## Top directory, in windows form if needed
## Use uname -s and not TARGET_OS (defined later) because we want unix path
## for msys shells.
###############################################################################

ifeq ("$(shell uname -s | grep -q -i mingw; echo $$?)","0")
  TOP_DIR := $(shell pwd -P -W)
else
  TOP_DIR := $(shell pwd -P)
endif

###############################################################################
## Import some variables from environment
###############################################################################

# Directories
ifndef ALCHEMY_WORKSPACE_DIR
  ALCHEMY_WORKSPACE_DIR := $(TOP_DIR)
endif

# Import target product from env
ifdef ALCHEMY_TARGET_PRODUCT
  TARGET_PRODUCT := $(ALCHEMY_TARGET_PRODUCT)
endif

# Import target product variant from env
ifdef ALCHEMY_TARGET_PRODUCT_VARIANT
  TARGET_PRODUCT_VARIANT := $(ALCHEMY_TARGET_PRODUCT_VARIANT)
endif

# Import target config dir from env
ifdef ALCHEMY_TARGET_CONFIG_DIR
  TARGET_CONFIG_DIR := $(ALCHEMY_TARGET_CONFIG_DIR)
endif

# Import target out dir from env
ifdef ALCHEMY_TARGET_OUT
  TARGET_OUT := $(ALCHEMY_TARGET_OUT)
endif

# Import skel dis from env
ifdef ALCHEMY_TARGET_SKEL_DIRS
  TARGET_SKEL_DIRS := $(ALCHEMY_TARGET_SKEL_DIRS)
endif

# Import scan add dirs from env
ifdef ALCHEMY_TARGET_SCAN_ADD_DIRS
  TARGET_SCAN_ADD_DIRS := $(ALCHEMY_TARGET_SCAN_ADD_DIRS)
endif

# Import scan prune dirs from env
ifdef ALCHEMY_TARGET_SCAN_PRUNE_DIRS
  TARGET_SCAN_PRUNE_DIRS := $(ALCHEMY_TARGET_SCAN_PRUNE_DIRS)
endif

# Import sdk dirs from env
ifdef ALCHEMY_TARGET_SDK_DIRS
  TARGET_SDK_DIRS := $(ALCHEMY_TARGET_SDK_DIRS)
endif

# Import host build dir from env
ifdef ALCHEMY_HOST_OUT_BUILD
  HOST_OUT_BUILD := $(ALCHEMY_HOST_OUT_BUILD)
endif

# Import host staging dir from env
ifdef ALCHEMY_HOST_OUT_STAGING
  HOST_OUT_STAGING := $(ALCHEMY_HOST_OUT_STAGING)
endif

###############################################################################
## Make sure TOP_DIR is ALCHEMY_WORKSPACE_DIR
###############################################################################
ifneq ("$(realpath $(TOP_DIR))","$(realpath $(ALCHEMY_WORKSPACE_DIR))")
  $(info ALCHEMY_WORKSPACE_DIR = $(ALCHEMY_WORKSPACE_DIR))
  $(info TOP_DIR = $(TOP_DIR))
  $(error TOP_DIR should be equal to ALCHEMY_WORKSPACE_DIR)
endif

###############################################################################
## Host preliminary setup.
###############################################################################
HOST_OS := $(shell $(BUILD_SYSTEM)/scripts/host.py OS)
HOST_ARCH := $(shell $(BUILD_SYSTEM)/scripts/host.py ARCH)

# No shared library for host modules
HOST_STATIC_LIB_SUFFIX := .a
ifeq ("$(HOST_OS)","windows")
  HOST_EXE_SUFFIX := .exe
else
  HOST_EXE_SUFFIX :=
endif

HOST_ROOT_DESTDIR := usr
HOST_DEFAULT_BIN_DESTDIR := usr/bin
HOST_DEFAULT_LIB_DESTDIR := usr/lib
HOST_DEFAULT_ETC_DESTDIR := etc

# Add --force-local to tar command on windows to avoid interpretation of ':'
# as network resource
TAR := tar
ifeq ("$(HOST_OS)","windows")
  TAR += --force-local
endif

###############################################################################
###############################################################################

# Global prerequisites (shall be used only by os makefile or product specific config)
# Make sure it is a simply expanded variable
ifndef TARGET_GLOBAL_PREREQUISITES
  TARGET_GLOBAL_PREREQUISITES :=
endif

# Include product env file
ifdef TARGET_CONFIG_DIR
  -include $(TARGET_CONFIG_DIR)/target-setup.mk
  -include $(TARGET_CONFIG_DIR)/product.mk
endif

# If a sdk has a target-setup.mk file, include it, otherwise include the legacy
# setup.mk file
TARGET_SDK_DIRS ?=
$(foreach __dir,$(TARGET_SDK_DIRS), \
	$(eval -include $(__dir)/target-setup.mk) \
	$(eval -include $(__dir)/setup.mk) \
)

###############################################################################
## Target OS aliases.
###############################################################################

# TARGET_OS aliases to simplify selection of android/iphone/iphonesimulator targets
ifdef TARGET_OS
  ifeq ("$(TARGET_OS)","android")
    override TARGET_OS := linux
    override TARGET_OS_FLAVOUR := android
  else ifeq ("$(TARGET_OS)","parrot")
    override TARGET_OS := linux
    override TARGET_OS_FLAVOUR := parrot
  else ifneq ("$(filter $(TARGET_OS),iphone ios)","")
    override TARGET_OS := darwin
    override TARGET_OS_FLAVOUR := iphoneos
  else ifneq ("$(filter $(TARGET_OS),iphonesimulator iossimulator)","")
    override TARGET_OS := darwin
    override TARGET_OS_FLAVOUR := iphonesimulator
  else ifeq ("$(TARGET_OS)","macos")
    override TARGET_OS := darwin
    override TARGET_OS_FLAVOUR := native
  else ifeq ("$(TARGET_OS)","yocto")
    override TARGET_OS := linux
    override TARGET_OS_FLAVOUR := yocto
  endif
endif

# Setup target specific variables
include $(BUILD_SYSTEM)/targets/setup.mk

# Setup Output directories
TARGET_OUT_PREFIX ?= Alchemy-out/
TARGET_OUT ?= $(TOP_DIR)/$(TARGET_OUT_PREFIX)$(TARGET_PRODUCT_FULL_NAME)
TARGET_OUT_BUILD ?= $(TARGET_OUT)/build
TARGET_OUT_DOC ?= $(TARGET_OUT)/doc
TARGET_OUT_STAGING ?= $(TARGET_OUT)/staging
TARGET_OUT_FINAL ?= $(TARGET_OUT)/final
TARGET_OUT_GCOV ?= $(TARGET_OUT)/gcov

HOST_OUT_BUILD ?= $(TARGET_OUT)/build-host
HOST_OUT_STAGING ?= $(TARGET_OUT)/staging-host

# Make sure that TARGET_DEPLOY_ROOT is not TARGET_OUT_STAGING (or one of its subdir)
ifdef TARGET_DEPLOY_ROOT
  ifneq ("$(call str-starts-with,$(TARGET_DEPLOY_ROOT),$(TARGET_OUT_STAGING))","")
    $(warning TARGET_DEPLOY_ROOT=$(TARGET_DEPLOY_ROOT))
    $(warning TARGET_OUT_STAGING=$(TARGET_OUT_STAGING))
    $(error TARGET_DEPLOY_ROOT should not starts with TARGET_OUT_STAGING)
  endif
endif

TARGET_CONFIG_PREFIX ?= Alchemy-config/
TARGET_CONFIG_DIR ?= $(TOP_DIR)/$(TARGET_CONFIG_PREFIX)$(TARGET_PRODUCT_FULL_NAME)

# Comptatiblity : use CONFIG_GLOBAL_FILE if defined
ifndef TARGET_GLOBAL_CONFIG_FILE
ifdef CONFIG_GLOBAL_FILE
  TARGET_GLOBAL_CONFIG_FILE := $(CONFIG_GLOBAL_FILE)
else
  TARGET_GLOBAL_CONFIG_FILE := $(TARGET_CONFIG_DIR)/global.config
endif
endif
override CONFIG_GLOBAL_FILE := $(TARGET_GLOBAL_CONFIG_FILE)

# Extra directories to skip/add during makefile scan
TARGET_SCAN_PRUNE_DIRS ?=
TARGET_SCAN_ADD_DIRS ?=

# Ignore config and out directorie(s)
ifneq ("$(dir $(TOP_DIR)/$(TARGET_CONFIG_PREFIX))","$(TOP_DIR)")
  TARGET_SCAN_PRUNE_DIRS += $(dir $(TOP_DIR)/$(TARGET_CONFIG_PREFIX))
endif
ifneq ("$(dir $(TOP_DIR)/$(TARGET_OUT_PREFIX))","$(TOP_DIR)")
  TARGET_SCAN_PRUNE_DIRS += $(dir $(TOP_DIR)/$(TARGET_OUT_PREFIX))
endif

# Skeleton directories
TARGET_SKEL_DIRS ?=

# Strip final directory
TARGET_NOSTRIP_FINAL ?= 0

# Python specific: generate 'pyc' files
TARGET_FINAL_PYTHON_GENERATE_PYC ?= 0
TARGET_FINAL_PYTHON_REMOVE_PY ?= 0

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

# Add a section in executable/shared library with dependencies used
TARGET_ADD_DEPENDS_SECTION ?= 0
TARGET_DEPENDS_SECTION_NAME ?= .alchemy.depends
ifneq ("$(TARGET_ADD_DEPENDS_SECTION)","0")
ifeq ("$(USE_GIT_REV)","0")
  $(warning TARGET_ADD_DEPENDS_SECTION requires USE_GIT_REV, disabling ...)
  TARGET_ADD_DEPENDS_SECTION := 0
endif
endif

ifdef TARGET_ADD_BUILDID_SECTION
ifneq ("$(TARGET_ADD_BUILDID_SECTION)","0")
$(warning TARGET_ADD_BUILDID_SECTION is no more supported)
endif
endif

# List of filenames to filter during strip (no wildcard allowed here because
# module.mk will also look in this list to filter, not only final.mk)
TARGET_STRIP_FILTER ?=

# List of files with permissions to be applied
# See documentation for format of file.
TARGET_PERMISSIONS_FILES ?=

# Set to 1 if the result of the compilation will be executed in a chroot
# environment. Used by some modules to adapt their configuration
TARGET_CHROOT ?= 0

ifdef TARGET_IMAGE_PATH_MAP_FILE
$(error TARGET_IMAGE_PATH_MAP_FILE is no more supported)
endif

# List of target wise build properties to be put in build.prop file
TARGET_BUILD_PROPERTIES ?=

# Include gdbserver (GPLv3) or not in target
TARGET_INCLUDE_GDBSERVER ?= 1

# Include TZData or not in the target
TARGET_INCLUDE_TZDATA ?= 0

# Include Gconv or not on the target
TARGET_INCLUDE_GCONV ?= 0

# Include libgfortran or not on the target
TARGET_INCLUDE_GFORTRAN ?= 0

# Enable c++ exceptions
TARGET_USE_CXX_EXCEPTIONS ?= 1

# Link cpio image inside the kernel.
TARGET_LINUX_LINK_CPIO_IMAGE ?= 0

# Generate a Uboot image of linux
TARGET_LINUX_GENERATE_UIMAGE ?= 0

# Proceed install device-tree blobs via kernel target build ('no' by default)
TARGET_LINUX_INSTALL_DEVICE_TREE ?= 0

# Copy device tree files to the boot directory
TARGET_LINUX_DEVICE_TREE_NAMES ?=

# TODO: remove compatibility with old name in future version
ifdef TARGET_LINUX_DEVICE_TREE
  $(warning TARGET_LINUX_DEVICE_TREE is deprecated, please use TARGET_LINUX_DEVICE_TREE_NAMES)
  TARGET_LINUX_DEVICE_TREE_NAMES += $(TARGET_LINUX_DEVICE_TREE)
endif

# Extra argument for linux build
TARGET_LINUX_MAKE_BUILD_ARGS ?=

# Linux source directory (required by some kernel drivers)
TARGET_LINUX_DIR ?=

ifeq ("$(TARGET_OS_FLAVOUR:-chroot=)","native")
  ifndef TARGET_LINUX_RELEASE
    TARGET_LINUX_RELEASE := $(shell uname -r)
  endif
endif

# Target image format (tar, cpio, ext2, ext3, ext4, plf)
# It can optionaly be suffixed with .gz, .bz2 or zip to compress the image
TARGET_IMAGE_FORMAT ?= tar.gz

# Target image generation options (not used for plf images)
# --size : size ((in bytes, suffixes K,M,G allowed)) of the image file
# --sparse : generate a sparse image
TARGET_IMAGE_OPTIONS ?=

# Generate the image with mke2fs
TARGET_IMAGE_FAST ?=

# Customize how final tree is done (what will be filtered)
# full: nothing filtered
# firmware: filtered according to internal heuristics suitable for embedded execution
TARGET_FINAL_MODE ?= firmware

# List of directories to add in ldconfig cache
TARGET_LDCONFIG_DIRS ?=

# Compatiblity when TARGET_ROOT_DESTDIR is not 'usr'
# Create a simlink from usr to the actual TARGET_ROOT_DESTDIR
# Note: this does NOT work if TARGET_ROOT_DESTDIR is a subdir of 'usr' (for
# example 'usr/local')
ifneq ("$(TARGET_ROOT_DESTDIR)","usr")
  ifneq ("$(patsubst usr/%,$(empty),$(TARGET_ROOT_DESTDIR))","")
    $(shell mkdir -p $(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR); \
        rm -f $(TARGET_OUT_STAGING)/usr; \
        ln -s $(TARGET_ROOT_DESTDIR) $(TARGET_OUT_STAGING)/usr; \
    )
  endif
endif

###############################################################################
## gobject-introspection setup.
###############################################################################
TARGET_XDG_DATA_DIRS := $(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR)/share
HOST_XDG_DATA_DIRS := $(HOST_OUT_STAGING)/$(HOST_ROOT_DESTDIR)/share
