###############################################################################
## @file baremetal/setup.mk
## @author R. Lefèvre
## @date 2015/01/05
##
## This file contains additional setup for baremetal.
###############################################################################

ifndef TARGET_CROSS
  export PATH := /opt/arm-2014q4-none-linaro/bin:$(PATH)
  TARGET_CROSS := /opt/arm-2014q4-none-linaro/bin/arm-none-eabi-
endif

# Force arm mode
TARGET_DEFAULT_ARM_MODE := arm

# Force static compilation
TARGET_FORCE_STATIC := 1

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
