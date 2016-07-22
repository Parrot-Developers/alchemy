###############################################################################
## @file coverage.mk
## @author Y.M. Morgan
## @date 2014/05/18
##
## Code coverage (gcov) helpers.
###############################################################################

# Only if code coverage is in use
ifeq ("$(USE_COVERAGE)","1")

###############################################################################
## Create boxinit rc file to setup gcov output files.
## GCOV_PREFIX_STRIP : will strip of $(TARGET_OUT_BUILD). We count numbers of
## '/' to determine number of components to remove.
## FIXME : It it ends with '/', an extra component will be removed.
## GCOV_PREFIX : will setup new 'root' for output.
###############################################################################
ifneq ("$(call is-module-in-build-config,boxinit)","")
__coverage_prefix_strip := $(words $(subst /,$(space),$(TARGET_OUT_BUILD)))
__coverage_rcfile := $(TARGET_OUT_STAGING)/$(TARGET_DEFAULT_ETC_DESTDIR)/boxinit.d/01-gcov.rc
$(__coverage_rcfile):
	@mkdir -p $(dir $@)
	@( \
		echo "on init"; \
		echo "    export GCOV_PREFIX_STRIP $(__coverage_prefix_strip)"; \
		echo "    export GCOV_PREFIX /var/lib/gcov"; \
	) > $@
$(ALL_BUILD_MODULES): $(__coverage_rcfile)
endif

###############################################################################
## Copy all .gcno files from build directory into $(TARGET_OUT)/gcov directory.
###############################################################################

# Create gcov directory
.PHONY: coverage-copy-gcno
coverage-copy-gcno:
	@echo "Copying gcno files..."
	@( \
		for f in $$(cd $(TARGET_OUT_BUILD) && find -name '*.gcno'); do \
			mkdir -p $$(dirname $(TARGET_OUT_GCOV)/$$f); \
			cp -af $(TARGET_OUT_BUILD)/$$f $(TARGET_OUT_GCOV)/$$f; \
		done \
	)
	@echo "Done copying gcno files"

# Clean gcov directory
.PHONY: coverage-copy-gcno-clean
coverage-copy-gcno-clean:
	$(Q) rm -rf $(TARGET_OUT_GCOV)

# Setup dependencies
coverage-copy-gcno: post-build
pre-final: coverage-copy-gcno
clobber: coverage-copy-gcno-clean

endif # ifeq ("$(USE_COVERAGE)","1")

