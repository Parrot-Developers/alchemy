###############################################################################
## @file dump-database.mk
## @author Y.M. Morgan
## @date 2012/11/28
##
## Dump of internal database for debugging purposes.
###############################################################################

###############################################################################
## Variables.
###############################################################################

# Where to store the xml
DUMP_DATABASE_XML_FILE := $(TARGET_OUT)/alchemy-database.xml

# Mode used to dump the xml
# - Dumping with 'info' is faster than with 'echo' but requires to wrap internally
#   a call to make with the same command line
# - Dumping with 'file' is faster than with 'info' but requires make v4.0
ifeq ("$(MAKE_HAS_FILE_FUNC)","1")
  __dump_xml_with_file := 1
else ifdef ALCHEMAKE_CMDLINE
  __dump_xml_with_info := 1
endif

###############################################################################
## Macros.
###############################################################################

# First things to do before dumping database
# Compute revision of all modules
__dump-database-setup = \
	$(if $(call strneq,$(USE_GIT_REV),0),$(call module-compute-revisions))

# This will dump everything
__dump-database = \
	$(info --------------------) \
	$(info Modules: $(__modules)) \
	$(foreach __mod,$(__modules), \
		$(info --------------------) \
		$(info $(__mod):) \
		$(info $(space4)BUILD:$(if $(call is-module-in-build-config,$(__mod)),yes,no)) \
		$(foreach __field,$(modules-fields-depends) $(vars-LOCAL), \
			$(call __dump-database-field,$(__field),$(strip $(__modules.$(__mod).$(__field)))) \
		) \
		$(foreach __field,$(macros-LOCAL), \
			$(call __dump-database-macro,$(__field),$(value __modules.$(__mod).$(__field))) \
		) \
	) \
	$(info --------------------)

# This will only dump dependencies
__dump-database-depends = \
	$(info --------------------) \
	$(info Modules: $(__modules)) \
	$(foreach __mod,$(__modules), \
		$(info --------------------) \
		$(info $(__mod):) \
		$(foreach __field,$(modules-fields-depends), \
			$(call __dump-database-field,$(__field),$(strip $(__modules.$(__mod).$(__field)))) \
		) \
	) \
	$(info --------------------)

# Dump a field if not empty
# $1 : field name
# $2 : field value
__dump-database-field = \
	$(if $2, \
		$(if $(call streq,$(words $2),1), \
			$(info $(space4)$1: $2), \
			$(info $(space4)$1: ) \
			$(foreach __fielditem,$2, \
				$(info $(space4)$(space4)$(__fielditem)) \
			) \
		) \
	)
# Dump a macro if not empty. Unlike __dump-database-field, it does not separate
# words on multiple lines.
# $1 : macro name
# $2 : macro value
__dump-database-macro = \
	$(if $2, \
		$(info $(space4)$1:) \
		$(info $2) \
	)

# Dump the full database in xml format
__dump-database-xml = \
	$(call __write-xml,<?xml version='1.0' encoding='UTF-8'?>) \
	$(call __write-xml,<alchemy>) \
	$(call __write-xml,<target>) \
	$(call __dump-database-var-xml,ALCHEMY_WORKSPACE_DIR,$(ALCHEMY_WORKSPACE_DIR)) \
	$(foreach __var,$(vars-TARGET) LINUX_CROSS, \
		$(call __dump-database-var-xml,$(__var),$(strip $(TARGET_$(__var)))) \
	) \
	$(call __write-xml,</target>) \
	$(call __write-xml,<target-setup>) \
	$(foreach __var,$(vars-TARGET_SETUP), \
		$(call __dump-database-var-xml,$(__var),$(strip $(TARGET_SETUP_$(__var)))) \
	) \
	$(call __write-xml,</target-setup>) \
	$(call __write-xml,<modules>) \
	$(foreach __mod,$(__modules), \
		$(eval __build := $(if $(call is-module-in-build-config,$(__mod)),yes,no)) \
		$(call __write-xml,$(space4)<module name='$(__mod)' build='$(__build)'>) \
		$(foreach __field,$(modules-fields-depends) $(vars-LOCAL), \
			$(call __dump-database-field-xml,$(__field),$(strip $(__modules.$(__mod).$(__field)))) \
		) \
		$(foreach __field,$(macros-LOCAL), \
			$(call __dump-database-field-xml,$(__field),$(value __modules.$(__mod).$(__field))) \
		) \
		$(call __write-xml,$(space4)</module>) \
	) \
	$(call __write-xml,</modules>) \
	$(call __write-xml,<custom-macros>) \
	$(foreach __macro,$(__custom-macros), \
		$(call __write-xml,$(space4)<macro name='$(__macro)'>) \
		$(call __write-xml,$(space4)$(space4)$(call escape-xml,$(value $(__macro)))) \
		$(call __write-xml,$(space4)</macro>) \
	) \
	$(call __write-xml,</custom-macros>) \
	$(call __write-xml,</alchemy>)

# Dump a field in xml format if not empty
# $1 : field name
# $2 : field value
__dump-database-field-xml = \
	$(if $2, \
		$(call __write-xml,$(space4)$(space4)<field name='$1'>) \
		$(call __write-xml,$(space4)$(space4)$(space4)<value>$(call escape-xml,$2)</value>) \
		$(call __write-xml,$(space4)$(space4)</field>) \
	) \

# Dump a variable in xml format (even if empty)
# $1 : variable name
# $2 : variable value
__dump-database-var-xml = \
	$(call __write-xml,$(space4)<var name='$1'>) \
	$(call __write-xml,$(space4)$(space4)<value>$(call escape-xml,$2)</value>) \
	$(call __write-xml,$(space4)</var>)

# We use the 'endl' to force a new line when macro is expanded. This avoids the
# need to put a ';' and a continuation line when the shell command is expanded.
# Otherwise the length of the single line of command generated will be too big
# to pass down the shell (several hundreds of KB)
ifdef __dump_xml_with_file
  __write-xml = $1$(endl)
else ifdef __dump_xml_with_info
  __write-xml = $(info $1)
else
  __write-xml = @echo -e "$(call escape-echo,$1)" >> $(DUMP_DATABASE_XML_FILE) $(endl)
endif

###############################################################################
## Rules.
###############################################################################

.PHONY: dump
dump:
	$(call __dump-database-setup)
	$(call __dump-database)

.PHONY: dump-depends
dump-depends:
	$(call __dump-database-depends)

# If we use the 'file' method, setup needs to be done in another rule to
# guarantee execution order
.PHONY: __dump-xml-setup
__dump-xml-setup:
	@echo "Database dump: start"
	@mkdir -p $(dir $(DUMP_DATABASE_XML_FILE))
	@rm -f $(DUMP_DATABASE_XML_FILE)
	@touch $(DUMP_DATABASE_XML_FILE)

.PHONY: dump-xml
dump-xml: __dump-xml-setup
ifdef __dumping-xml
	@# Called inside a sub-make to dump using 'info' in a file
	$(call __dump-database-setup)
	$(info @@@@@XML-BEGIN@@@@@)
	$(call __dump-database-xml)
	$(info @@@@@XML-END@@@@@)
else
ifdef __dump_xml_with_file
	$(call __dump-database-setup)
	$(file > $(DUMP_DATABASE_XML_FILE),$(call __dump-database-xml))
else ifdef __dump_xml_with_info
	@# Force passing TARGET_ARCH because it was unexported in setup.mk
	+@( \
		tmpfile=$$(mktemp tmp.XXXXXXXXXX); \
		$(filter-out $(MAKECMDGOALS),$(ALCHEMAKE_CMDLINE)) \
			USE_SCAN_CACHE=1 \
			TARGET_ARCH=$(TARGET_ARCH) \
			__dumping-xml=1 \
			dump-xml &> $${tmpfile}; \
		n1=$$(($$(grep -hne "@@@@@XML-BEGIN@@@@@" $${tmpfile} | cut -d: -f1)+1)); \
		n2=$$(($$(grep -hne "@@@@@XML-END@@@@@" $${tmpfile} | cut -d: -f1)-1)); \
		sed -ne "$${n1},$${n2}p" $${tmpfile} > $(DUMP_DATABASE_XML_FILE); \
		rm -f $${tmpfile}; \
	)
else
	$(call __dump-database-setup)
	$(call __dump-database-xml)
endif
	@echo "Database dump: done -> $(DUMP_DATABASE_XML_FILE)"
endif

.PHONY: dump-xml-clean
dump-xml-clean:
	$(Q) rm -f $(DUMP_DATABASE_XML_FILE)

clobber: dump-xml-clean
