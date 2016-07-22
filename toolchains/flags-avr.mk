###############################################################################
## @file toolchains/flags-avr.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Setup toolchain variables.
###############################################################################

TARGET_GLOBAL_CFLAGS += -gdwarf-2
TARGET_GLOBAL_CFLAGS += -Os
TARGET_GLOBAL_CFLAGS += -fpack-struct
TARGET_GLOBAL_CFLAGS += -fshort-enums
TARGET_GLOBAL_CFLAGS += -funsigned-bitfields
TARGET_GLOBAL_CFLAGS += -funsigned-char
TARGET_GLOBAL_CFLAGS += -std=gnu99

ifdef TARGET_CPU
  TARGET_GLOBAL_CFLAGS += -mmcu=$(TARGET_CPU)
  TARGET_GLOBAL_LDFLAGS += -mmcu=$(TARGET_CPU)
endif
