###############################################################################
## @file oss-packages.mk
## @author Y.M. Morgan
## @date 2014/03/23
##
## Generate packages of Open Source Software modules.
###############################################################################

ifdef OSS_PACKAGES

OSS_PACKAGES_DIR := $(TARGET_OUT)/oss-packages

# Prepare packaging a module
# $1 : module name
oss-gen-package-prepare = \
	version=$(__modules.$1.ARCHIVE_VERSION); \
	if [ "$${version}" = "" ]; then \
		cd $(__modules.$1.PATH); \
		version=$$($(BUILD_SYSTEM)/scripts/getversion.sh $1); \
	fi; \
	atom=$(wildcard $(__modules.$1.PATH)/$(USER_MAKEFILE_NAME)); \
	config=$(wildcard $(abspath $(call module-get-config,$1))); \
	outpkg=$(OSS_PACKAGES_DIR)/$1-$${version}.tar.bz2; \
	echo "Packaging $1 version $${version}";

# Create package from archive
# $1 : module name
oss-gen-package-from-archive = \
	$(call oss-gen-package-prepare,$1) \
	inpkg=$(__modules.$1.PATH)/$(__modules.$1.ARCHIVE); \
	patches="$(addprefix $(__modules.$1.PATH)/,$(__modules.$1.ARCHIVE_PATCHES))"; \
	tar --transform="s|[^/]*/||g" -Pcjf \
		$${outpkg} $${inpkg} $${patches} $${atom} $${config};

# Create package from git
# $1 : module name
oss-gen-package-from-git = \
	$(call oss-gen-package-prepare,$1) \
	gitdir=$(__modules.$1.PATH); \
	gitarchive=$(OSS_PACKAGES_DIR)/git/$1-$${version}.tar; \
	patches=; \
	cd $${gitdir} && git archive --prefix=$1-$${version}/ -o $${gitarchive} HEAD; \
	tar --transform="s|[^/]*/||g" -Pcjf \
		$${outpkg} $${gitarchive} $${patches} $${atom} $${config};

# Create package
# $1 : module name
oss-gen-package = \
	$(if $(__modules.$1.MODULE), \
		$(if $(__modules.$1.ARCHIVE), \
			$(call oss-gen-package-from-archive,$1), \
			$(call oss-gen-package-from-git,$1) \
		), \
		$(info Unknown module $1) \
	)

ifeq ("$(OSS_PACKAGES)","all")
  override OSS_PACKAGES := $(__modules)
endif

.PHONY: oss-packages
oss-packages:
	@echo "Packages: start"
	@rm -rf $(OSS_PACKAGES_DIR)
	@mkdir -p $(OSS_PACKAGES_DIR)
	@mkdir -p $(OSS_PACKAGES_DIR)/git
	$(foreach __mod,$(sort $(OSS_PACKAGES)), \
		@$(call oss-gen-package,$(__mod))$(endl) \
	)
	@rm -rf $(OSS_PACKAGES_DIR)/git
	@echo "Packages: done -> $(OSS_PACKAGES_DIR)"

else

# Nothing to do
.PHONY: oss-packages
oss-packages:
	@echo "Packages: OSS_PACKAGES is not defined or empty"
endif
