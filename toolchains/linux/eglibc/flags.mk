###############################################################################
## @file toolchains/linux/eglibc/flags.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Additional flags for linux/eglibc toolchain.
###############################################################################

# Assume everybody will wants this
TARGET_GLOBAL_LDLIBS += -pthread -lrt
TARGET_GLOBAL_CFLAGS += -funwind-tables

# Enable link optimization for binutils's ld.
# gnu hash not supported by mips ABI
ifeq ("$(TARGET_ARCH)","mips")
  TARGET_GLOBAL_LDFLAGS += -Wl,-O1
else ifeq ("$(TARGET_ARCH)","mips64")
  TARGET_GLOBAL_LDFLAGS += -Wl,-O1
else
  TARGET_GLOBAL_LDFLAGS += -Wl,-O1,--hash-style=both
endif
