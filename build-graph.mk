###############################################################################
## @file build-graph.mk
## @author Y.M. Morgan
## @date 2012/10/19
##
## Rules to generate a graph of build dependencies.
###############################################################################

BUILD_GRAPH_DOT := $(TARGET_OUT)/build-graph.dot
BUILD_GRAPH_SVG := $(TARGET_OUT)/build-graph.svg
BUILD_GRAPH_PDF := $(TARGET_OUT)/build-graph.pdf

# Build the graph header
build-graph-header: .FORCE
	@echo "Generating $(call path-from-top,${BUILD_GRAPH_DOT})"
	@mkdir -p $(dir $@)
	$(Q)( \
		echo 'digraph G {'; \
		echo '  rankdir=LR;'; \
	) > ${BUILD_GRAPH_DOT}

# Build the graph for a single module
build-graph-%: build-graph-header
	$(if $(call is-module-in-build-config,$*), \
		$(Q)( \
			true; \
			$(foreach __mod2,$(call module-get-depends,$*), \
				echo '  "$*" -> "$(__mod2)";'; \
			) \
		)  >> ${BUILD_GRAPH_DOT} \
	)

$(BUILD_GRAPH_DOT): $(addprefix build-graph-,$(__modules))
	$(Q)( \
		echo '}' \
	) >> ${BUILD_GRAPH_DOT}

$(BUILD_GRAPH_SVG): $(BUILD_GRAPH_DOT)
	@echo "Generating $(call path-from-top,$@)"
	$(Q) dot -Tsvg -Nshape=box -o $@ $<

$(BUILD_GRAPH_PDF): $(BUILD_GRAPH_DOT)
	@echo "Generating $(call path-from-top,$@)"
	$(Q) dot -Tpdf -Nshape=box -o $@ $<


.PHONY: build-graph
build-graph: $(BUILD_GRAPH_SVG) $(BUILD_GRAPH_PDF)

.PHONY: build-graph-clean
build-graph-clean:
	@rm -f $(BUILD_GRAPH_DOT)
	@rm -f $(BUILD_GRAPH_SVG)
	@rm -f $(BUILD_GRAPH_PDF)

clobber: build-graph-clean
