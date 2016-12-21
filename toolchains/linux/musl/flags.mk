###############################################################################
## @file toolchains/linux/musl/flags.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Additional flags for linux/musl toolchain.
###############################################################################

# Assume everybody will wants this
TARGET_GLOBAL_LDLIBS += -pthread -lrt
TARGET_GLOBAL_CFLAGS += -funwind-tables
