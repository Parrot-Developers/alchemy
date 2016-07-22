###############################################################################
## @file toolchains/baremetal/flags.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Additional flags for baremetal toolchain.
###############################################################################

TARGET_GLOBAL_C_INCLUDES += \
	$(TARGET_OUT_STAGING)/include

TARGET_GLOBAL_CFLAGS += \
	-ffunction-sections \
	-fdata-sections \
	-fno-exceptions \
	-D__BAREMETAL__

TARGET_GLOBAL_CXXFLAGS += \
	-fno-rtti \
	-fno-use-cxa-atexit \
	-fno-exceptions \
	-funwind-tables

TARGET_GLOBAL_LDFLAGS += \
	-Wl,-static \

TARGET_GLOBAL_LDLIBS += \
	-lgcc
