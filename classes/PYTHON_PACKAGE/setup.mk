###############################################################################
## @file classes/PYTHON_PACKAGE/setup.mk
## @author Y.M. Morgan
## @date 2019/01/11
##
## Setup PYTHON_PACKAGE modules.
###############################################################################

# Dynamically get the 'major.minor' version of python
# $1: python binary
_python-pkg-get-python-version = \
	$(strip $(shell $1 -c \
		"import sys; print('{0.major:d}.{0.minor:d}'.format(sys.version_info))"))

# Dynamically construct the PYTHONPATH variable
# $1: python version
_python-pkg-get-python-path = \
	$(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR)/lib/python$1:$(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR)/lib/python$1/site-packages

_python-pkg-get-python-lib-path = \
	$(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR)/lib/python$1

# Dynamically copy sysconfigdata from sdk to staging if needed
# $1: python version
_python-pkg-copy-sysconfigdata = \
	$(foreach __sdk,$(TARGET_SDK_DIRS), \
		$(eval __src := $(wildcard $(__sdk)/$(TARGET_ROOT_DESTDIR)/lib/python$1/_sysconfigdata_*.py)) \
		$(if $(__src), \
			$(eval __dst := $(TARGET_OUT_STAGING)/$(TARGET_ROOT_DESTDIR)/lib/python$1/$(notdir $(__src))) \
			$(shell mkdir -p $(dir $(__dst)); \
				cp -af $(__src) $(__dst).$$$$ &> /dev/null; \
				if [ ! -f $(__dst) ]; then mv $(__dst).$$$$ $(__dst); \
				elif ! cmp -s $(__dst).$$$$ $(__dst) &>/dev/null; then mv $(__dst).$$$$ $(__dst); \
				else rm -f $(__dst).$$$$ &> /dev/null; \
				fi; \
			) \
		) \
	)

# Dynamically get the name of the sysconfigdata file of python
# $1: python library path
_python-pkg-get-sysconfigdata-name = \
	$(basename $(notdir $(wildcard $1/_sysconfigdata_*.py)))

# Need to be dynamically expanded in commands
_python-pkg-get-extra-env = \
	$(if $(or $(PRIVATE_NEED_PYTHONPATH),$(PRIVATE_NEED_SYSCONFIGDATA)), \
		$(eval _python-pkg-version := \
			$(call _python-pkg-get-python-version,$(PRIVATE_PYTHON))) \
		$(eval _python-pkg-path := \
			$(call _python-pkg-get-python-path,$(_python-pkg-version))) \
		$(eval _python-pkg-lib-path := \
			$(call _python-pkg-get-python-lib-path,$(_python-pkg-version))) \
		$(call _python-pkg-copy-sysconfigdata,$(_python-pkg-version)) \
		$(eval _python-pkg-sysconfigdata-name := \
			$(call _python-pkg-get-sysconfigdata-name,$(_python-pkg-lib-path))) \
		$(if $(PRIVATE_NEED_PYTHONPATH),PYTHONPATH="$(_python-pkg-path)") \
		$(if $(PRIVATE_NEED_SYSCONFIGDATA),_PYTHON_SYSCONFIGDATA_NAME="$(_python-pkg-sysconfigdata-name)") \
	)

# Build and install in the same command because the build directory can only be
# specified for the build command...
define _python-pkg-def-cmd-build
	@if [ ! -e "$(PRIVATE_PYTHON)" ]; then \
		echo "Missing python binary: '$(PRIVATE_PYTHON)'"; \
		exit 1; \
	fi
	$(Q) cd $(dir $(PRIVATE_SRC_DIR)/$(PRIVATE_SETUP_PY)) && \
		$(PRIVATE_ENV) \
		$(_python-pkg-get-extra-env) \
		$(PRIVATE_PYTHON) $(notdir $(PRIVATE_SETUP_PY)) \
		build \
		$(PRIVATE_BUILD_ARGS) \
		install \
		$(PRIVATE_INSTALL_ARGS)
endef

# TODO: clean python packages
define _python-pkg-def-cmd-clean
endef
