###############################################################################
## @file classes/PYTHON_EXTENSION/setup.mk
## @author Y.M. Morgan
## @date 2016/03/20
##
## Setup PYTHON_EXTENSION modules.
###############################################################################

define _python-ext-def-cmd-build
	@mkdir -p $(PRIVATE_BUILD_DIR)
	$(Q) cd $(dir $(PRIVATE_SETUP_PY_FILE)) && \
		$(PRIVATE_SETUP_PY_ENV) \
		$(PRIVATE_EXTRA_SETUP_PY_ENV) \
		$(PRIVATE_PYTHON) setup.py \
		build $(PRIVATE_BUILD_ARGS) \
		install $(PRIVATE_INSTALL_ARGS) \
		$(PRIVATE_EXTRA_SETUP_PY_ARGS)
endef

define _python-ext-def-cmd-clean
	$(Q) if [ -f $(PRIVATE_INSTALL_RECORD_FILE) ]; then \
		cat $(PRIVATE_INSTALL_RECORD_FILE) | xargs rm -f; \
		rm -f $(PRIVATE_INSTALL_RECORD_FILE); \
	fi
	$(Q) if [ -f $(PRIVATE_SETUP_PY_FILE) ]; then \
		cd $(dir $(PRIVATE_SETUP_PY_FILE)) && \
			$(PRIVATE_SETUP_PY_ENV) \
			$(PRIVATE_PYTHON) setup.py \
			clean $(PRIVATE_CLEAN_ARGS) \
			|| echo "Ignoring clean errors"; \
	fi
endef
