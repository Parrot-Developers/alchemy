###############################################################################
## @file avr-setup.mk
## @author T. Morassi
## @date 2016/01/08
##
## This file contains additional setup for arm toolchain.
###############################################################################

TARGET_GLOBAL_CFLAGS += -gdwarf-2
TARGET_GLOBAL_CFLAGS += -mmcu=${TARGET_CPU}
TARGET_GLOBAL_CFLAGS += -Os
TARGET_GLOBAL_CFLAGS += -fpack-struct
TARGET_GLOBAL_CFLAGS += -fshort-enums
TARGET_GLOBAL_CFLAGS += -funsigned-bitfields
TARGET_GLOBAL_CFLAGS += -funsigned-char
TARGET_GLOBAL_CFLAGS += -Wall
TARGET_GLOBAL_CFLAGS += -Wstrict-prototypes
TARGET_GLOBAL_CFLAGS += -std=gnu99

TARGET_GLOBAL_LDFLAGS := -mmcu=${TARGET_CPU}
