###############################################################################
## @file classes/setup.mk
## @author Y.M. Morgan
## @date 2016/03/09
##
## Setup module classes.
###############################################################################

# Internal module classes
_classes_internal := \
	EXECUTABLE \
	SHARED_LIBRARY \
	STATIC_LIBRARY \
	LIBRARY \
	PREBUILT

# External module classes
# AUTOTOOLS shall be first, its setup.mk defines some variables needed by other
# module classes
_classes_external := \
	AUTOTOOLS \
	CMAKE \
	QMAKE \
	PYTHON_EXTENSION \
	CUSTOM \
	META_PACKAGE \
	GI_TYPELIB \
	LINUX \
	LINUX_MODULE

# All module classes
_classes := \
	$(_classes_internal) \
	$(_classes_external)

include $(BUILD_SYSTEM)/classes/GENERIC/setup.mk
include $(BUILD_SYSTEM)/classes/BINARY/setup.mk
include $(BUILD_SYSTEM)/classes/codecheck-setup.mk

# Setup the BUILD_XXX variable with the name of the makefile for registration
# Also include the makefile for class specific setup (optional)
$(foreach _cls,$(_classes), \
	$(eval BUILD_$(_cls) := $(BUILD_SYSTEM)/classes/$(_cls)/register.mk) \
	$(eval -include $(BUILD_SYSTEM)/classes/$(_cls)/setup.mk) \
)
