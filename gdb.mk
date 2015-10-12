###############################################################################
## @file gdb.mk
## @author Y.M. Morgan
## @date 2013/02/18
##
## Gdb helper file generation.
###############################################################################

GDB_WRAPPER_SCRIPT := $(TARGET_OUT)/alchemy.gdb

GDB_ABSOLUTE_PREFIX := $(TARGET_OUT_STAGING)
GDB_SEARCH_PATH :=
GDB_DEBUG_FILE_DIR :=

ifeq ("$(TARGET_OS)","linux")
ifeq ("$(TARGET_OS_FLAVOUR)","native-chroot")
  GDB_DEBUG_FILE_DIR := $(TARGET_OUT_FINAL)/usr/lib/debug
  GDB_ABSOLUTE_PREFIX := $(TARGET_OUT_FINAL)
endif
endif

ifneq ("$(TOOLCHAIN_LIBC)","")
  GDB_SEARCH_PATH := $(TOOLCHAIN_LIBC)/lib
  GDB_SEARCH_PATH := $(GDB_SEARCH_PATH):$(TOOLCHAIN_LIBC)/usr/lib
endif

# Create a wrapper to be used in gdb with internal macro 'set-lib-path'
$(GDB_WRAPPER_SCRIPT):
	@mkdir -p $(dir $@)
	@rm -f $@
	@echo "Gdb wrapper: $@"
	@echo "define set-lib-path" >> $@
	@echo "  set solib-absolute-prefix $(GDB_ABSOLUTE_PREFIX)" >> $@
ifneq ("$(GDB_SEARCH_PATH)","")
	@echo "  set solib-search-path $(GDB_SEARCH_PATH)" >> $@
endif
ifneq ("$(GDB_DEBUG_FILE_DIR)","")
	@echo "  set debug-file-directory $(GDB_DEBUG_FILE_DIR)" >> $@
endif
	@echo "end" >> $@
	@echo "set-lib-path" >> $@

.PHONY: gdb-wrapper
gdb-wrapper: $(GDB_WRAPPER_SCRIPT)

.PHONY: gdb-wrapper-clean
gdb-wrapper-clean:
	$(Q) rm -f $(GDB_WRAPPER_SCRIPT)

post-build: gdb-wrapper
clobber: gdb-wrapper-clean
