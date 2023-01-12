###############################################################################
## @file final.mk
## @author Y.M. Morgan
## @date 2012/11/05
##
## Final tree generation.
###############################################################################

###############################################################################
## Determine arguments to script.
###############################################################################

MAKEFINAL_SCRIPT := $(BUILD_SYSTEM)/scripts/makefinal.py
LDCONFIG := $(BUILD_SYSTEM)/scripts/ldconfig.py
GENPYC_SCRIPT := $(BUILD_SYSTEM)/scripts/genpyc.py

ifneq ("$(V)","0")
  MAKEFINAL_SCRIPT += -v
  LDCONFIG += -v
  GENPYC_SCRIPT += -v
endif

MAKEFINAL_ARGS :=

# Stripping kernel modules requires --strip-debug option and its
# specific strip program
ifneq ("$(TARGET_NOSTRIP_FINAL)","1")
  ifneq ("$(TARGET_STRIP)","")
      MAKEFINAL_ARGS += --strip="$(TARGET_STRIP)"
  endif
  ifeq ("$(TARGET_OS)","linux")
    ifneq ("$(TARGET_LINUX_CROSS)","")
      MAKEFINAL_ARGS += --strip-kernel="$(TARGET_LINUX_CROSS)strip --strip-debug"
    endif
  endif
endif

ifneq ("$(TARGET_SKEL_DIRS)","")
  $(foreach d,$(TARGET_SKEL_DIRS),$(eval MAKEFINAL_ARGS += --skel="$(d)"))
endif

# Create very minimal skeleton for linux (some absolute required directories)
ifeq ("$(TARGET_OS)","linux")
ifeq ("$(is-full-system)","1")
  MAKEFINAL_ARGS += --linux-basic-skel
endif
endif

# Valgrind requires its libraries etc to be unstripped
MAKEFINAL_ARGS += \
    --strip-filter="usr/libexec/valgrind"

# When python is used, keep its files, otherwise filter them (default)
ifneq ("$(call is-module-in-build-config,python)","")
  MAKEFINAL_ARGS += --keep-python-files
endif
ifneq ("$(call is-module-in-build-config,python3)","")
  MAKEFINAL_ARGS += --keep-python-files
endif

# Remove write access to 'group' and 'other'. For native only, a fixstat tools
# is used on other variant when generating the image
ifeq ("$(TARGET_OS_FLAVOUR)","native-chroot")
  MAKEFINAL_ARGS += --remove-wgo
endif

# Additional files to filter during strip
MAKEFINAL_ARGS += \
	$(foreach __lib,$(TARGET_STRIP_FILTER),--strip-filter="$(__lib)")

MAKEFINAL_ARGS += \
	--filelist=$(TARGET_OUT)/filelist.txt

# generation mode
MAKEFINAL_ARGS += \
	--mode=$(TARGET_FINAL_MODE)

# Construct contents of ld.so.preload
_ld_so_preload_contents := $(strip $(foreach __mod,$(ALL_BUILD_MODULES), \
	$(__modules.$(__mod).LDPRELOAD) \
))

###############################################################################
## Internal generation of final tree.
##
## Create /etc/ld.so.conf and create cache with ldconfig
## We use a clone of ldconfig to handle correctly cross architecture.
## Do not recreate missing links (-X option).
##
## Check that there is no missing libraies needed by some binaries and that
## there is no DT_RPATH flag set.
###############################################################################
.PHONY: __final-internal
__final-internal:
	@echo "Generating final tree..."
ifneq ("$(TARGET_OS_FLAVOUR)","native-chroot")
ifneq ("$(TARGET_OS_FLAVOUR)","native")
	$(Q) rm -rf $(TARGET_OUT_FINAL)
endif
endif
	$(Q) $(MAKEFINAL_SCRIPT) $(MAKEFINAL_ARGS) \
		$(TARGET_OUT_STAGING) $(TARGET_OUT_FINAL) $(TARGET_OUT)/final.mk
	$(Q) $(MAKE) -f $(TARGET_OUT)/final.mk
	@mkdir -p $(TARGET_OUT_FINAL)/$(TARGET_DEFAULT_ETC_DESTDIR)
ifeq ("$(TARGET_FINAL_PYTHON_GENERATE_PYC)","1")
# Use compiled host version of python to generate pyc to make sure that at runtime
# It works properly
	$(Q) if [ -e $(HOST_OUT_STAGING)/usr/bin/python ]; then \
		echo "Generating pyc files from python files"; \
		$(HOST_OUT_STAGING)/usr/bin/python $(GENPYC_SCRIPT) \
			--sysroot $(TARGET_OUT_FINAL) \
			$(TARGET_OUT_FINAL); \
	fi
ifneq ("$(TARGET_FINAL_PYTHON_REMOVE_PY)","")
# The '/' at the end of the directory is important in case it's a symlink
	$(foreach __dir,$(TARGET_FINAL_PYTHON_REMOVE_PY), \
		$(Q) if [ -d $(TARGET_OUT_FINAL)/$(__dir)/ ]; then \
			echo "Removing '*.py' files from '$(__dir)' directory"; \
			find $(TARGET_OUT_FINAL)/$(__dir)/ -name '*.py' -delete; \
		fi$(endl) \
	)
endif
endif
ifeq ("$(TARGET_OS)","linux")
ifeq ("$(is-full-system)","1")
	@if [ ! -e $(TARGET_OUT_FINAL)/$(TARGET_DEFAULT_ETC_DESTDIR)/ld.so.conf ]; then \
		( \
			echo "/lib/$(TARGET_TOOLCHAIN_TRIPLET)"; \
			echo "/lib"; \
			echo "/$(TARGET_DEFAULT_LIB_DESTDIR)/$(TARGET_TOOLCHAIN_TRIPLET)"; \
			echo "/$(TARGET_DEFAULT_LIB_DESTDIR)"; \
			$(foreach __d,$(TARGET_LDCONFIG_DIRS),echo "$(__d)";) \
		) >> $(TARGET_OUT_FINAL)/$(TARGET_DEFAULT_ETC_DESTDIR)/ld.so.conf; \
	fi
	$(Q) $(LDCONFIG) -X -r $(TARGET_OUT_FINAL)
ifneq ("$(_ld_so_preload_contents)","")
	@( \
		preload="$(TARGET_OUT_FINAL)/$(TARGET_DEFAULT_ETC_DESTDIR)/ld.so.preload"; \
		touch $${preload}; \
		for entry in $(_ld_so_preload_contents); do \
			if ! grep -q "$${entry}" $${preload}; then \
				echo "$${entry}" >> $${preload}; \
			fi \
		done \
	)
endif
endif
endif
ifeq ("$(is-full-system)","1")
	$(Q) $(BUILD_SYSTEM)/scripts/checkdyndeps.py $(TARGET_OUT_FINAL)
endif
	@echo `date +%s` > $(TARGET_OUT_FINAL)/$(TARGET_DEFAULT_ETC_DESTDIR)/final.stamp
	@echo "Done generating final tree"

.PHONY: final
final: __final-internal

.PHONY: final-clean
final-clean:
	@echo "Deleting final directory..."
	$(Q)rm -rf $(TARGET_OUT_FINAL)
	$(Q)rm -f $(TARGET_OUT)/filelist.txt
	$(Q)rm -f $(TARGET_OUT)/final.mk

###############################################################################
## Setup dependencies.
## Do not clean when in native or native-chroot mode
###############################################################################
__final-internal: pre-final
ifneq ("$(TARGET_OS_FLAVOUR)","native-chroot")
ifneq ("$(TARGET_OS_FLAVOUR)","native")
clobber: final-clean
endif
endif
