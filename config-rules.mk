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
	$(call __call-confwrapper,--diff check)
	@echo "All configs are up to date"

# Check everything at once, in silence, stopping in case not up to date
.PHONY: __config-check
__config-check:
ifdef TARGET_TEST
	@echo "Config check disabled under test : TARGET_TEST=$(TARGET_TEST)"
else ifneq ("$(USE_CONFIG_CHECK)","0")
	$(call __call-confwrapper,check)
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
	$(eval __CONFIG_DISABLE_RUNTIME_DEPS := 1)
	$(call __call-confwrapper,update)
	$(eval __CONFIG_DISABLE_RUNTIME_DEPS := 0)
endif

# Update everything at once
.PHONY: config-update
config-update:
	$(call __call-confwrapper,update)

# Configure everything at once using default user interface (qconf)
.PHONY: config
config:
	$(call __call-confwrapper,config)

# Configure everything at once using qconf
.PHONY: xconfig
xconfig:
	$(call __call-confwrapper,--ui=qconf config)

# Configure everything at once using mconf
.PHONY: menuconfig
menuconfig:
	$(call __call-confwrapper,--ui=mconf config)

# Configure everything at once using nconf
.PHONY: nconfig
nconfig:
	$(call __call-confwrapper,--ui=nconf config)
