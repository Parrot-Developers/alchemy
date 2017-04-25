###############################################################################
## @file libc.mk
## @author Y.M. Morgan
## @date 2015/04/11
##
## This file contains logic to install libc files from toolchain to staging.
###############################################################################

LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

ifneq ("$(TARGET_ROOT_DESTDIR)","usr")
  $(warning TARGET_ROOT_DESTDIR=$(TARGET_ROOT_DESTDIR))
  $(error Installing libc is not supported if TARGET_ROOT_DESTDIR is not 'usr')
endif

LOCAL_MODULE := libc
LOCAL_MODULE_FILENAME := $(LOCAL_MODULE).done

# File indicating that installation was done
_libc_installed_file := $(call local-get-build-dir)/$(LOCAL_MODULE).installed

# The sysroot of the toolchain
# (after removing trailing '/' it can become empty if it was just '/')
_libc_sysroot := $(patsubst %/,%,$(TOOLCHAIN_LIBC))

# architecture dependent sub-directory
_libc_arch_subdir := $(TARGET_TOOLCHAIN_TRIPLET)

# List of files to be put in /lib or /lib/<arch>
_libc_lib_names := \
	ld \
	libasan \
	libc \
	libcrypt \
	libdl \
	libgcc_s \
	libgomp \
	libm \
	libnsl \
	libnss_compat \
	libnss_db \
	libnss_dns \
	libnss_files \
	libnss_hesiod \
	libnss_nis \
	libnss_nisplus \
	libpthread \
	libresolv \
	librt \
	libSegFault \
	libthread_db \
	libutil

# List of files to be put in /usr/lib or /usr/lib/<arch>
_libc_usrlib_names := \
	libstdc++ \
	libgcc_s

ifeq ("$(TARGET_LIBC)","musl")
  _libc_usrlib_names += libc
endif

# 'lib' directory
_libc_lib_dir := $(_libc_sysroot)/lib
_libc_lib_arch_dir := $(_libc_sysroot)/lib/$(_libc_arch_subdir)
ifeq ("$(TARGET_ARCH)","x64")
  _libc_lib64_dir := $(_libc_sysroot)/lib64
endif

# 'usr/lib' directory
_libc_usrlib_dir := $(_libc_sysroot)/usr/lib
_libc_usrlib_arch_dir := $(_libc_sysroot)/usr/lib/$(_libc_arch_subdir)

# 'usr/lib/debug/lib' directory
_libc_lib_dbg_dir := $(_libc_sysroot)/usr/lib/debug/lib
_libc_lib_dbg_arch_dir := $(_libc_sysroot)/usr/lib/debug/lib/$(_libc_arch_subdir)

# List of files to be put in /lib and /lib/<arch>
_libc_lib_files :=
_libc_lib_arch_files :=
$(foreach __f,$(_libc_lib_names), \
	$(eval _libc_lib_files += \
		$(wildcard $(_libc_lib_dir)/$(__f).so*) \
		$(wildcard $(_libc_lib_dir)/$(__f)-*.so) \
	) \
	$(eval _libc_lib_arch_files += \
		$(wildcard $(_libc_lib_arch_dir)/$(__f).so*) \
		$(wildcard $(_libc_lib_arch_dir)/$(__f)-*.so) \
	) \
)

# Linker links
_libc_lib_files += $(wildcard $(_libc_lib_dir)/$(notdir $(TARGET_LOADER)))
_libc_lib_arch_files += $(wildcard $(_libc_lib_arch_dir)/$(notdir $(TARGET_LOADER)))
ifeq ("$(TARGET_ARCH)","x64")
  _libc_lib_files += $(wildcard $(_libc_lib64_dir)/$(notdir $(TARGET_LOADER)))
endif

# List of files to be put in /usr/lib and /usr/lib/<arch>
_libc_usrlib_files +=
_libc_usrlib_arch_files +=
$(foreach __f,$(_libc_usrlib_names), \
	$(eval _libc_usrlib_files += \
		$(wildcard $(_libc_usrlib_dir)/$(__f).so*) \
		$(wildcard $(_libc_usrlib_dir)/$(__f)-*.so) \
	) \
	$(eval _libc_usrlib_arch_files += \
		$(wildcard $(_libc_usrlib_arch_dir)/$(__f).so*) \
		$(wildcard $(_libc_usrlib_arch_dir)/$(__f)-*.so) \
	) \
)

# List of files to be put in /usr/lib/debug/lib and /usr/lib/debug/lib/<arch>
_libc_lib_dbg_files :=
_libc_lib_dbg_arch_files :=
$(foreach __f,$(_libc_lib_names), \
	$(eval _libc_lib_dbg_files += \
		$(wildcard $(_libc_lib_dbg_dir)/$(__f)-*.so) \
	) \
	$(eval _libc_lib_dbg_arch_files += \
		$(wildcard $(_libc_lib_dbg_arch_dir)/$(__f)-*.so) \
	) \
)

# Some toolchains, such as recent Linaro toolchains, store GCC support libraries
# (libstdc++, libgcc_s, etc.) outside of the sysroot
ifeq ("$(findstring libstdc++,$(_libc_usrlib_files) $(_libc_usrlib_arch_files))","")
  _libc_support_dir_cmd := $(TARGET_CC) $(TARGET_GLOBAL_CFLAGS)
  ifeq ("$(TARGET_ARCH)","arm")
    _libc_support_dir_cmd += $(TARGET_GLOBAL_CFLAGS_$(TARGET_DEFAULT_ARM_MODE))
  endif
  _libc_support_dir_cmd += -print-file-name=libstdc++.a
  _libc_support_dir := $(wildcard $(dir $(shell $(_libc_support_dir_cmd))))
  _libc_lib_files += $(wildcard $(_libc_support_dir)/libgcc_s*.so*)
  _libc_usrlib_files += $(wildcard $(_libc_support_dir)/libstdc++*.so*)
endif

# Musl libc is all in one.
ifeq ("$(TARGET_LIBC)","musl")
  LOCAL_CREATE_LINKS := $(TARGET_LOADER):/usr/lib/libc.so
endif

# Remove gdb python file
_libc_lib_files := $(filter-out %.py,$(_libc_lib_files))
_libc_lib_arch_files := $(filter-out %.py,$(_libc_lib_arch_files))
_libc_usrlib_files := $(filter-out %.py,$(_libc_usrlib_files))
_libc_usrlib_arch_files := $(filter-out %.py,$(_libc_usrlib_arch_files))
_libc_lib_dbg_files := $(filter-out %.py,$(_libc_lib_dbg_files))
_libc_lib_dbg_arch_files := $(filter-out %.py,$(_libc_lib_dbg_arch_files))

# Timezone data
_libc_tzdata :=
ifneq ("$(TARGET_INCLUDE_TZDATA)","0")
  _libc_tzdata := $(wildcard $(_libc_sysroot)/usr/share/zoneinfo)
endif

# Locale data
_libc_gconv :=
ifneq ("$(TARGET_INCLUDE_GCONV)","0")
  _libc_gconv := $(wildcard $(_libc_sysroot)/usr/lib/$(_libc_arch_subdir)/gconv)
  ifeq ("$(_libc_gconv)","")
    _libc_gconv := $(wildcard $(_libc_sysroot)/usr/lib/gconv)
  endif
endif

# Fortran libraries
_libc_gfortran :=
ifneq ("$(TARGET_INCLUDE_GFORTRAN)","0")
  _libc_gfortran := $(wildcard $(_libc_support_dir)/libgfortran*.so*)
endif

# ldd
_libc_ldd := $(wildcard $(_libc_sysroot)/usr/bin/ldd)

# Copy a list of files
# $1: list of files
# $2: destination directory (relative to $(TARGET_OUT_STAGING))
_libc_copy_files = \
	$(if $1, \
		@mkdir -p $(TARGET_OUT_STAGING)/$2$(endl) \
		$(foreach __f,$1, \
			$(Q) cp -af $(__f) $(TARGET_OUT_STAGING)/$2/$(notdir $(__f))$(endl) \
		) \
	)

# Install rule
# use $(endl) to separate commands on separate lines
$(_libc_installed_file): $(BUILD_SYSTEM)/toolchains/libc.mk
	@mkdir -p $(dir $@)
	$(call _libc_copy_files,$(_libc_lib_files),lib)
	$(call _libc_copy_files,$(_libc_lib_arch_files),lib/$(_libc_arch_subdir))
	$(call _libc_copy_files,$(_libc_usrlib_files),usr/lib)
	$(call _libc_copy_files,$(_libc_usrlib_arch_files),usr/lib/$(_libc_arch_subdir))
	$(call _libc_copy_files,$(_libc_lib_dbg_files),usr/lib/debug/lib)
	$(call _libc_copy_files,$(_libc_lib_dbg_arch_files),usr/lib/debug/lib/$(_libc_arch_subdir))
	$(if $(_libc_tzdata), \
		@mkdir -p $(TARGET_OUT_STAGING)/usr/share/zoneinfo$(endl) \
		$(Q) cp -Raf $(_libc_tzdata)/* $(TARGET_OUT_STAGING)/usr/share/zoneinfo$(endl) \
	)
	$(if $(_libc_gconv), \
		@mkdir -p $(TARGET_OUT_STAGING)/usr/lib/gconv$(endl) \
		$(Q) cp -Raf $(_libc_gconv)/* $(TARGET_OUT_STAGING)/usr/lib/gconv$(endl) \
	)
	$(if $(_libc_gfortran), \
		$(call _libc_copy_files,$(_libc_gfortran),lib) \
	)
	$(if $(_libc_ldd), \
		@mkdir -p $(TARGET_OUT_STAGING)/usr/bin$(endl) \
		$(Q) cp -af $(_libc_ldd) $(TARGET_OUT_STAGING)/usr/bin$(endl) \
		$(Q) sed -i.bak -e 's|^\#! */bin/bash$$|\#!/bin/sh|' $(TARGET_OUT_STAGING)/usr/bin/ldd$(endl) \
		@rm -f $(TARGET_OUT_STAGING)/usr/bin/ldd.bak$(endl) \
	)
# Link /lib64 -> /lib
ifeq ("$(TARGET_ARCH)","x64")
	$(Q) [ -e $(TARGET_OUT_STAGING)/lib64 ] || ln -sf lib $(TARGET_OUT_STAGING)/lib64
endif
ifeq ("$(TARGET_ARCH)","aarch64")
	$(Q) [ -e $(TARGET_OUT_STAGING)/lib64 ] || ln -sf lib $(TARGET_OUT_STAGING)/lib64
	$(Q) [ -e $(TARGET_OUT_STAGING)/usr/lib64 ] || ln -sf lib $(TARGET_OUT_STAGING)/usr/lib64
endif
# Include gdbserver only if requested (GPLv3)
ifneq ("$(TARGET_INCLUDE_GDBSERVER)","0")
ifneq ("$(TOOLCHAIN_GDBSERVER)","")
	@mkdir -p $(TARGET_OUT_STAGING)/usr/bin
	$(Q) cp -af $(TOOLCHAIN_GDBSERVER) $(TARGET_OUT_STAGING)/usr/bin/gdbserver
endif
endif
	@touch $@

# Clean rule
# use $(endl) to separate commands on separate lines
.PHONY: $(LOCAL_MODULE)-clean
$(LOCAL_MODULE)-clean:
	$(foreach __f,$(_libc_lib_files), \
		$(Q) rm -f $(TARGET_OUT_STAGING)/lib/$(notdir $(__f))$(endl) \
	)
	$(foreach __f,$(_libc_usrlib_files), \
		$(Q) rm -f $(TARGET_OUT_STAGING)/usr/lib/$(notdir $(__f))$(endl) \
	)
	$(foreach __f,$(_libc_dbg_files), \
		$(Q) rm -f $(TARGET_OUT_STAGING)/usr/lib/debug/lib/$(notdir $(__f))$(endl) \
	)
# Link /lib64 -> /lib
ifeq ("$(TARGET_ARCH)","x64")
	$(Q) rm -f $(TARGET_OUT_STAGING)/lib64
endif
	$(Q) rm -rf $(TARGET_OUT_STAGING)/usr/share/zoneinfo
	$(Q) rm -rf $(TARGET_OUT_STAGING)/usr/lib/gconv
	$(Q) rm -f $(TARGET_OUT_STAGING)/usr/bin/ldd
	$(Q) rm -f $(TARGET_OUT_STAGING)/usr/bin/gdbserver

# Register 'installed' file in build system
$(call local-get-build-dir)/$(LOCAL_MODULE_FILENAME): $(_libc_installed_file)
LOCAL_DONE_FILES += $(notdir $(_libc_installed_file))
LOCAL_CLEAN_FILES += $(_libc_installed_file)
LOCAL_CUSTOM_TARGETS += $(_libc_installed_file)

# Make sure this is the first module built
TARGET_GLOBAL_PREREQUISITES += $(call local-get-build-dir)/$(LOCAL_MODULE_FILENAME)

# Prebuilt so it is always enabled and does not appear in config
include $(BUILD_PREBUILT)
