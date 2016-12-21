###############################################################################
## @file toolchains/ecos/flags.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Additional flags for ecos toolchain.
###############################################################################

TARGET_GLOBAL_C_INCLUDES += \
	$(TARGET_OUT_STAGING)/ecos/include \
	$(BUILD_SYSTEM)/toolchains/ecos/include

TARGET_GLOBAL_CFLAGS += \
	-mno-thumb-interwork \
	-ffunction-sections \
	-fdata-sections \
	-fno-exceptions \
	-D__ECOS__

TARGET_GLOBAL_CXXFLAGS += \
	-fno-rtti \
	-fno-use-cxa-atexit \
	-fno-exceptions \
	-funwind-tables

TARGET_GLOBAL_LDFLAGS += \
	-Wl,-static \
	-nostdlib
