###############################################################################
## @file classes/LINUX/rules-perf.mk
## @author Y.M. Morgan
## @date 2016/03/20
##
## Rules for LINUX/perf modules.
###############################################################################

_module_msg := $(if $(_mode_host),Host )Perf

include $(BUILD_SYSTEM)/classes/GENERIC/rules.mk

# General setup
PERF_MAKE_ENV := \
	LDFLAGS="$(TARGET_GLOBAL_LDFLAGS)" \
	EXTRA_CFLAGS="$(TARGET_GLOBAL_CFLAGS) $(call normalize-system-c-includes,$(TARGET_GLOBAL_C_INCLUDES))"

PERF_MAKE_ARGS := \
	NO_DWARF=1 \
	NO_NEWT=1 \
	NO_DEMANGLE=1

# Build rule
$(LOCAL_BUILD_MODULE):
	@mkdir -p $(dir $@)
	$(Q) $(PERF_MAKE_ENV) $(MAKE) $(PERF_MAKE_ARGS) \
		ARCH=$(TARGET_ARCH) CROSS_COMPILE=$(TARGET_CROSS) \
		O=$(PRIVATE_BUILD_DIR) -C $(PRIVATE_PATH)/tools/perf
	$(Q) mkdir -p $(TARGET_OUT_STAGING)/$(TARGET_DEFAULT_BIN_DESTDIR)
	$(Q) cp -af $(PRIVATE_BUILD_DIR)/perf $(TARGET_OUT_STAGING)/$(TARGET_DEFAULT_BIN_DESTDIR)
	@touch $@

# Clean rule
.PHONY: perf-clean
perf-clean:
	$(Q) if [ -d $(LINUX_BUILD_DIR) ]; then \
		$(PERF_MAKE_ENV) $(MAKE) $(PERF_MAKE_ARGS) \
			ARCH=$(LINUX_ARCH) CROSS_COMPILE=$(TARGET_CROSS) \
			O=$(PRIVATE_BUILD_DIR) -C $(PRIVATE_PATH)/tools/perf --ignore-errors \
			clean || echo "Ignoring clean errors"; \
	fi
	$(Q) rm -f $(TARGET_OUT_STAGING)/$(TARGET_DEFAULT_BIN_DESTDIR)/perf
