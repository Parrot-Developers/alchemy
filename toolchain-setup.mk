###############################################################################
## @file toolchain-setup.mk
## @author Y.M. Morgan
## @date 2016/03/08
###############################################################################

# If product has a toolchain-setup.mk file, include it
ifdef TARGET_CONFIG_DIR
  -include $(TARGET_CONFIG_DIR)/toolchain-setup.mk
endif

# If a sdk has a toolchain-setup.mk file, include it
TARGET_SDK_DIRS ?=
$(foreach __dir,$(TARGET_SDK_DIRS), \
	$(eval -include $(__dir)/toolchain-setup.mk) \
)

# Remember all TARGET_XXX variables from external setup
# FIXME: using := causes trouble if one of the sdk setup file has done a +=
# on a TARGET variable and used a not yet defined variable
#
# For example:
# TARGET_GLOBAL_LDFLAGS += \
#     -L$(TARGET_OUT_STAGING)/usr/lib/arm-linux-gnueabihf/tegra
# TARGET_OUT_STAGING is NOT yet defined, it will be after
#
# It works because the var will be recursive and not immediate
# So we use macro-copy and after full setup value will be correct.
$(foreach __var,$(vars-TARGET_SETUP), \
	$(if $(call is-var-defined,TARGET_$(__var)), \
		$(call macro-copy,TARGET_SETUP_$(__var),TARGET_$(__var)) \
	) \
)

# User specific debug setup makefile
debug-setup-makefile := Alchemy-debug-setup.mk
ifneq ("$(wildcard $(TOP_DIR)/$(debug-setup-makefile))","")
  ifneq ("$(V)","0")
    $(info Including $(TOP_DIR)/$(debug-setup-makefile))
  endif
  include $(TOP_DIR)/$(debug-setup-makefile)
endif

# Setup toolchain specific variables
include $(BUILD_SYSTEM)/toolchains/setup.mk

###############################################################################
## Copy content of host staging from sdks.
## Required because some modules expect to find tools in $(HOST_OUT_STAGING)
## even if it came from a sdk.
###############################################################################

# Copy content of host staging from a sdk
__sdk-copy-host = \
	$(eval __file := $(HOST_OUT_STAGING)/sdk_$(subst /,_,$1).done) \
	$(shell \
		if [ $1/$(USER_MAKEFILE_NAME) -nt $(__file) ]; then \
			$(info Copying $1/host/ to $(HOST_OUT_STAGING)) \
			mkdir -p $(HOST_OUT_STAGING); \
			cp -Raf $1/host/* $(HOST_OUT_STAGING); \
			touch $(__file); \
		fi \
	)

$(foreach __dir,$(TARGET_SDK_DIRS), \
	$(if $(wildcard $(__dir)/host), \
		$(call __sdk-copy-host,$(__dir)) \
	) \
)
