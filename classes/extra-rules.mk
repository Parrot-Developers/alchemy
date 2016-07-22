###############################################################################
## @file classes/extra-rules.mk
## @author Y.M. Morgan
## @date 2016/05/1
##
## Extra rules for module classes not build related (doc, codecheck...).
###############################################################################

###############################################################################
## Documentation generation rules.
###############################################################################

$(LOCAL_MODULE)-doc: PRIVATE_DOC_DIR := $(TARGET_OUT_DOC)/$(LOCAL_MODULE)

ifneq ("$(LOCAL_DOXYFILE)","")

LOCAL_DOXYFILE := \
	$(if $(call is-path-absolute,$(LOCAL_DOXYFILE)), \
		$(LOCAL_DOXYFILE), \
		$(addprefix $(LOCAL_PATH)/,$(LOCAL_DOXYFILE)) \
	)

# If a doxyfile has been defined by the user, we use it
# Check if the input paths are absolute and if not, correct them
_module_doc_input := $(shell egrep '^INPUT *=' $(LOCAL_DOXYFILE) | sed 's/^INPUT *=//g')
_module_doc_input += $(LOCAL_DOXYGEN_INPUT)
_module_doc_input := $(foreach __path,$(_module_doc_input), \
	$(if $(call is-path-absolute,$(__path)), \
		$(__path),$(addprefix $(LOCAL_PATH)/,$(__path)) \
	))

$(LOCAL_MODULE)-doc: PRIVATE_INPUT := $(_module_doc_input)
$(LOCAL_MODULE)-doc: PRIVATE_DOXYFILE := $(LOCAL_DOXYFILE)

# Use the doxyfile, but override output to out/doc and input with absolute paths
.PHONY: $(LOCAL_MODULE)-doc
$(LOCAL_MODULE)-doc:
	@echo "$(PRIVATE_MODULE): Generating doxygen documentation from $(PRIVATE_DOXYFILE)"
	@rm -rf $(PRIVATE_DOC_DIR)
	@mkdir -p $(PRIVATE_DOC_DIR)
	@cd $(PRIVATE_PATH) && ( \
		cat $(PRIVATE_DOXYFILE); \
		echo "PROJECT_NAME=$(PRIVATE_MODULE)"; \
		echo "PROJECT_BRIEF=\"$(PRIVATE_DESCRIPTION)\""; \
		echo "INPUT=$(PRIVATE_INPUT)"; \
		echo "EXCLUDE_PATTERNS+=.git out sdk"; \
		echo "OUTPUT_DIRECTORY=$(PRIVATE_DOC_DIR)"; \
	) | doxygen - &> $(PRIVATE_DOC_DIR)/doxygen.log
else

# Use LOCAL_PATH and other input
_module_doc_input := $(LOCAL_PATH) $(LOCAL_DOXYGEN_INPUT)
_module_doc_input := $(foreach __path,$(_module_doc_input), \
	$(if $(call is-path-absolute,$(__path)), \
		$(__path),$(addprefix $(LOCAL_PATH)/,$(__path)) \
	))

$(LOCAL_MODULE)-doc: PRIVATE_INPUT := $(_module_doc_input)

# If no doxyfile has been defined by the user, we generate one on the fly from
# a template created by doxygen which tries to document all and for all
# languages
# We disable warnings because they are plenty in this case
.PHONY: $(LOCAL_MODULE)-doc
$(LOCAL_MODULE)-doc:
	@echo "$(PRIVATE_MODULE): Generating doxygen documentation from generated doxyfile"
	@rm -rf $(PRIVATE_DOC_DIR)
	@mkdir -p $(PRIVATE_DOC_DIR)
	@cd $(PRIVATE_PATH) && ( \
		doxygen -g -; \
		echo "PROJECT_NAME=$(PRIVATE_MODULE)"; \
		echo "PROJECT_BRIEF=\"$(PRIVATE_DESCRIPTION)\""; \
		echo "EXTRACT_ALL=YES"; \
		echo "GENERATE_LATEX=NO"; \
		echo "WARNINGS=NO"; \
		echo "WARN_IF_DOC_ERROR=NO"; \
		echo "RECURSIVE=YES"; \
		echo "INPUT=$(PRIVATE_INPUT)"; \
		echo "EXCLUDE_PATTERNS+=.git out sdk"; \
		echo "OUTPUT_DIRECTORY=$(PRIVATE_DOC_DIR)"; \
	) | doxygen - &> $(PRIVATE_DOC_DIR)/doxygen.log

endif

###############################################################################
## cloc (count line of code) rules.
###############################################################################

# Use codecheck source lists
_cloc_files := $(_codecheck_as_files)
_cloc_files += $(_codecheck_c_files)
_cloc_files += $(_codecheck_cxx_files)
_cloc_files += $(_codecheck_objc_files)
_cloc_files += $(_codecheck_vala_files)

# Sort to have unique names
_cloc_files := $(sort $(_cloc_files))

$(LOCAL_MODULE)-cloc: PRIVATE_CLOC_FILES := $(_cloc_files)

.PHONY: $(LOCAL_MODULE)-cloc
$(LOCAL_MODULE)-cloc:
	@mkdir -p $(PRIVATE_BUILD_DIR)
	@:> $(PRIVATE_BUILD_DIR)/cloc-list.txt
	@for f in $(PRIVATE_CLOC_FILES); do \
		echo $${f} >> $(PRIVATE_BUILD_DIR)/cloc-list.txt; \
	done
	$(Q) cloc --list-file=$(PRIVATE_BUILD_DIR)/cloc-list.txt \
		--by-file --xml \
		--out $(PRIVATE_BUILD_DIR)/cloc.xml
