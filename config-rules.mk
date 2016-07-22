###############################################################################
## @file config-rules.mk
## @author Y.M. Morgan
## @date 2012/08/31
##
## Configuration management, rules.
###############################################################################

# Check config file when needed, another check will be done with USE_CONFIG_CHECK
# but with warning
ifeq ("$(SKIP_CONFIG_CHECK)","0")
$(TARGET_GLOBAL_CONFIG_FILE): __config-check
endif

###############################################################################
## Full configuration rules.
###############################################################################

# Check everything at once
.PHONY: config-check
config-check:
	$(eval __args := $(call __generate-config-args))
	@( \
		if $(CONFWRAPPER) --main=$(TARGET_GLOBAL_CONFIG_FILE) --diff check $(__args); then \
			echo "All configs are up to date"; \
		else \
			exit 1; \
		fi; \
	)

# Check everything at once, in silence, stopping in case not up to date
.PHONY: __config-check
__config-check:
ifdef TARGET_TEST
	@echo "Config check disabled under test : TARGET_TEST=$(TARGET_TEST)"
else ifneq ("$(USE_CONFIG_CHECK)","0")
	$(eval __args := $(call __generate-config-args))
	@$(CONFWRAPPER) --main=$(TARGET_GLOBAL_CONFIG_FILE) check $(__args)
else
	@echo "Config check disabled : USE_CONFIG_CHECK=$(USE_CONFIG_CHECK)"
endif
	@mkdir -p $(TARGET_OUT)
	@cp -af $(TARGET_GLOBAL_CONFIG_FILE) $(TARGET_OUT)/global.config

# Generate a global.config will all modules activated
# As it uses ALL_BUILD_MODULES it will be a no op if the file alredy exists.
# ALL_BUILD_MODULES is set to really all module only if no previous file.
# Mainly used for automatic builds with a sdk
.PHONY: config-force-all
config-force-all:
ifeq ("$(GLOBAL_CONFIG_FILE_AVAILABLE)","1")
	@echo "Ignoring 'config-force-all', '$(TARGET_GLOBAL_CONFIG_FILE)' exists"
else
	@mkdir -p $(dir $(TARGET_GLOBAL_CONFIG_FILE))
	@:>$(TARGET_GLOBAL_CONFIG_FILE)
	$(foreach __mod,$(ALL_BUILD_MODULES), \
		@echo "CONFIG_ALCHEMY_BUILD_$(call module-get-define,$(__mod))=y" \
			>> $(TARGET_GLOBAL_CONFIG_FILE)$(endl) \
	)
	$(eval __args := $(call __generate-config-args))
	@$(CONFWRAPPER) --main=$(TARGET_GLOBAL_CONFIG_FILE) update $(__args)
endif

# Update everything at once
.PHONY: config-update
config-update:
	$(eval __args := $(call __generate-config-args))
	@$(CONFWRAPPER) --main=$(TARGET_GLOBAL_CONFIG_FILE) update $(__args)

# Configure everything at once using default user interface (qconf)
.PHONY: config
config:
	$(eval __args := $(call __generate-config-args))
	@$(CONFWRAPPER) --main=$(TARGET_GLOBAL_CONFIG_FILE) config $(__args)

# Configure everything at once using qconf
.PHONY: xconfig
xconfig:
	$(eval __args := $(call __generate-config-args))
	@$(CONFWRAPPER) --main=$(TARGET_GLOBAL_CONFIG_FILE) --ui=qconf config $(__args)

# Configure everything at once using mconf
.PHONY: menuconfig
menuconfig:
	$(eval __args := $(call __generate-config-args))
	@$(CONFWRAPPER) --main=$(TARGET_GLOBAL_CONFIG_FILE) --ui=mconf config $(__args)

# Configure everything at once using nconf
.PHONY: nconfig
nconfig:
	$(eval __args := $(call __generate-config-args))
	@$(CONFWRAPPER) --main=$(TARGET_GLOBAL_CONFIG_FILE) --ui=nconf config $(__args)

