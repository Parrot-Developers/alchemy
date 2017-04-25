###############################################################################
## @file gdb.mk
## @author Y.M. Morgan
## @date 2013/02/18
##
## Gdb helper file generation.
###############################################################################

GDB_WRAPPER_SCRIPT := $(TARGET_OUT)/alchemy.gdb

GDB_ABSOLUTE_PREFIX :=
GDB_SEARCH_PATH :=
GDB_DEBUG_FILE_DIR :=

# On non-native build, use the staging directory as abolute prefix
# Otherwise simply add 'bin', 'usr/bin', 'lib' and 'usr/lib' from staging dir
# in search path
ifneq ("$(TARGET_OS_FLAVOUR)","native")
  GDB_ABSOLUTE_PREFIX := $(TARGET_OUT_STAGING)
else
  GDB_SEARCH_PATH += $(TARGET_OUT_STAGING)/bin
  GDB_SEARCH_PATH += $(TARGET_OUT_STAGING)/$(TARGET_DEFAULT_BIN_DESTDIR)
  GDB_SEARCH_PATH += $(TARGET_OUT_STAGING)/lib/$(TARGET_TOOLCHAIN_TRIPLET)
  GDB_SEARCH_PATH += $(TARGET_OUT_STAGING)/lib
  GDB_SEARCH_PATH += $(TARGET_OUT_STAGING)/$(TARGET_DEFAULT_LIB_DESTDIR)/$(TARGET_TOOLCHAIN_TRIPLET)
  GDB_SEARCH_PATH += $(TARGET_OUT_STAGING)/$(TARGET_DEFAULT_LIB_DESTDIR)
endif

# Extra search path from toolchain
ifneq ("$(TOOLCHAIN_LIBC)","")
ifneq ("$(TOOLCHAIN_LIBC)","/")
  GDB_SEARCH_PATH += $(TOOLCHAIN_LIBC)/lib
  GDB_SEARCH_PATH += $(TOOLCHAIN_LIBC)/usr/lib
endif
endif

# TODO: usr/lib/debug could be available for other OS.
ifeq ("$(TARGET_OS)","linux")
ifeq ("$(TARGET_OS_FLAVOUR)","native-chroot")
  GDB_DEBUG_FILE_DIR := $(TARGET_OUT_STAGING)/usr/lib/debug
endif
endif

# Create a wrapper to be used in gdb with internal macro 'set-lib-path'
$(GDB_WRAPPER_SCRIPT): .FORCE
	@mkdir -p $(dir $@)
	@rm -f $@.tmp
	@echo "define set-lib-path" >> $@.tmp
ifneq ("$(GDB_ABSOLUTE_PREFIX)","")
	@echo "  set solib-absolute-prefix $(GDB_ABSOLUTE_PREFIX)" >> $@.tmp
endif
ifneq ("$(GDB_SEARCH_PATH)","")
	@echo "  set solib-search-path $(subst $(space),:,$(strip $(GDB_SEARCH_PATH)))" >> $@.tmp
endif
ifneq ("$(GDB_DEBUG_FILE_DIR)","")
	@echo "  set debug-file-directory $(GDB_DEBUG_FILE_DIR)" >> $@.tmp
endif
	@echo "end" >> $@.tmp
	@echo "set-lib-path" >> $@.tmp
	$(call update-file-if-needed-msg,$@,$@.tmp,"Gdb wrapper: $@")

.PHONY: gdb-wrapper
gdb-wrapper: $(GDB_WRAPPER_SCRIPT)

.PHONY: gdb-wrapper-clean
gdb-wrapper-clean:
	$(Q) rm -f $(GDB_WRAPPER_SCRIPT)

post-build: gdb-wrapper
clobber: gdb-wrapper-clean
