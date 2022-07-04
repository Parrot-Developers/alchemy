###############################################################################
## @file classes/LINUX/rules-perf.mk
## @author Y.M. Morgan
## @date 2016/03/20
##
## Rules for LINUX/perf modules.
###############################################################################

_module_msg := $(if $(_mode_host),Host )Perf

include $(BUILD_SYSTEM)/classes/GENERIC/rules.mk

ifeq ("$(TARGET_ARCH)","x64")
PERF_ARCH := x86_64
else ifeq ("$(TARGET_ARCH)","aarch64")
PERF_ARCH := arm64
else
PERF_ARCH := $(TARGET_ARCH)
endif

# General setup
PERF_MAKE_ENV := \
	LDFLAGS="$(TARGET_GLOBAL_LDFLAGS)" \
	EXTRA_CFLAGS="$(TARGET_GLOBAL_CFLAGS) $(call normalize-system-c-includes,$(TARGET_GLOBAL_C_INCLUDES),TARGET)"

# Preserve CC from Yocto env (to preserve --sysroot)
ifeq ("$(TARGET_OS_FLAVOUR)","yocto")
PERF_MAKE_ENV += CC="$(TARGET_CC)"
endif

PERF_MAKE_ARGS := \
	NO_DWARF=1 \
	NO_NEWT=1 \
	HAVE_CPLUS_DEMANGLE_SUPPORT=1

# Build rule
$(LOCAL_BUILD_MODULE):
	@mkdir -p $(dir $@)
	$(Q) $(PERF_MAKE_ENV) $(MAKE) $(PERF_MAKE_ARGS) \
		ARCH=$(PERF_ARCH) CROSS_COMPILE=$(TARGET_CROSS) DESTDIR=$(TARGET_OUT_STAGING) prefix=/$(TARGET_ROOT_DESTDIR) \
		O=$(PRIVATE_BUILD_DIR) -C $(PRIVATE_PATH)/tools/perf
	$(Q) mkdir -p $(TARGET_OUT_STAGING)/$(TARGET_DEFAULT_BIN_DESTDIR)
	$(Q) cp -af $(PRIVATE_BUILD_DIR)/perf $(TARGET_OUT_STAGING)/$(TARGET_DEFAULT_BIN_DESTDIR)
	@touch $@

# Clean rule
.PHONY: perf-clean
perf-clean:
	$(Q) if [ -d $(LINUX_BUILD_DIR) ]; then \
		$(PERF_MAKE_ENV) $(MAKE) $(PERF_MAKE_ARGS) \
			ARCH=$(PERF_ARCH) CROSS_COMPILE=$(TARGET_CROSS) \
			O=$(PRIVATE_BUILD_DIR) -C $(PRIVATE_PATH)/tools/perf --ignore-errors \
			clean || echo "Ignoring clean errors"; \
	fi
	$(Q) rm -f $(TARGET_OUT_STAGING)/$(TARGET_DEFAULT_BIN_DESTDIR)/perf
