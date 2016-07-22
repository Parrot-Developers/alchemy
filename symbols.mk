###############################################################################
## @file symbols.mk
## @author Y.M. Morgan
## @date 2013/04/20
##
## Generate an archive with debugging symbols from staging directory.
###############################################################################

SYMBOLS_FILE := $(TARGET_OUT)/symbols-$(TARGET_PRODUCT_FULL_NAME).tar
MAKESYMBOLS_SCRIPT := $(BUILD_SYSTEM)/scripts/makesymbols.py

ifneq ("$(V)","0")
  MAKESYMBOLS_SCRIPT += -v
endif

.PHONY: __symbols-tar-internal
__symbols-tar-internal: symbols-clean
	@echo "Symbols: start"
	$(Q) $(MAKESYMBOLS_SCRIPT) $(TARGET_OUT_STAGING) $(SYMBOLS_FILE)

# Tar archive, no compression
.PHONY: symbols-tar
symbols-tar: __symbols-tar-internal
	@echo "Symbols: done -> $(SYMBOLS_FILE)"

# Tar archive gzip compressed
.PHONY: symbols-tar-gz
symbols-tar-gz: __symbols-tar-internal
	@echo "Symbols: compressing"
	$(Q) gzip $(SYMBOLS_FILE)
	@echo "Symbols: done -> $(SYMBOLS_FILE).gz"

# Tar archive bzip2 compressed
.PHONY: symbols-tar-bz2
symbols-tar-bz2: __symbols-tar-internal
	@echo "Symbols: compressing"
	$(Q) bzip2 $(SYMBOLS_FILE)
	@echo "Symbols: done -> $(SYMBOLS_FILE).bz2"

.PHONY: symbols-clean
symbols-clean:
	$(Q) rm -f $(SYMBOLS_FILE)
	$(Q) rm -f $(SYMBOLS_FILE).gz
	$(Q) rm -f $(SYMBOLS_FILE).bz2

# Compatiblility
.PHONY: symbols
symbols: symbols-tar-gz

# Setup dependencies
__symbols-tar-internal: post-build
clobber: symbols-clean
