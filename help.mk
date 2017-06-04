###############################################################################
## @file help.mk
## @author Y.M. Morgan
## @date 2013/01/22
###############################################################################

###############################################################################
## Help rules.
###############################################################################

.PHONY: help
help:
	@echo "Main targets:"
	@echo "  all     : build everything."
	@echo "  clean   : same as clobber."
	@echo "  dirclean: same as clobber."
	@echo "  clobber : delete output directory (build, staging, final)."
	@echo "  scan    : force a rescan of workspace in case the makefile cache is used."
	@echo "  final   : generate the final tree from the staging directory."
	@echo "  plf     : generate the plf image from the final tree."
	@echo ""
	@echo "Module targets:"
	@echo "  <module>                 : build specified module."
	@echo "  <module>-clean           : clean specified module."
	@echo "  <module>-cloc            : count number of lines of code with cloc."
	@echo "  <module>-doc             : generate a documentation for the specified module."
	@echo "  <module>-dirclean        : clean specified module and delete its build directory."
	@echo "  <module>-path            : print location of module."
	@echo "  <module>-codeformat      : format code for the specified module."
	@echo "  <module>-codecheck       : check coding rules for the specified module."
	@echo "  <module>-genproject-<ide>: generate ide config for <ide>. <ide> could be : \"$(genproject-get-ides)\"."
	@echo ""
	@echo "Main configuration targets:"
	@echo "  config       : configure the build as well as modules."
	@echo "  config-check : check all config files."
	@echo "  config-update: update all config files with new options."
	@echo ""
	@echo "Other available frontends for configuration:"
	@echo "  xconfig   : use qconf (Qt), default."
	@echo "  menuconfig: use mconf (ncurses)."
	@echo "  nconf     : use nconf (ncurses, basic)."
	@echo ""
	@echo "Other targets:"
	@echo "  help        : display this help message."
	@echo "  help-modules: display the list of registered modules."
	@echo "  dump        : dump the full module database."
	@echo "  dump-depends: dump dependencies of module database."
	@echo "  dump-xml    : dump the full module database in xml format."
	@echo "  build-graph : create a graph of build dependencies."
	@echo "  sdk         : create a sdk from current confing."
	@echo "  symbols     : create an archive with debugging symbols."
	@echo "  var-<VAR>   : print the contents of variable <VAR>."
	@echo ""
	@echo "  genproject-<KIND>: generate project for <KIND> ($(GENPROJECT_KINDS))."
	@echo "  genproject-help  : display help about generate-<KIND>."
	@echo ""
	@echo "Usefull variables:"
	@echo "  V: set to 1 to activate verbose mode."
	@echo "  F: set to 1 to activate force mode (modules built externally will be re-checked)."
	@echo "  W: set to 1 to activate more compilation warnings."
	@echo "  USE_SCAN_CACHE: use the previous cache of makefiles to speedup scan."
	@echo "  USE_COLORS    : activate colors in output."

.PHONY: help-modules
help-modules:
	@echo "List of registered modules ($(words $(ALL_MODULES))):"
	@echo "$(ALL_MODULES)"

