###############################################################################
## @file toolchains/linux/eglibc/flags.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Additional flags for linux/eglibc toolchain.
###############################################################################

# Assume everybody will wants this
TARGET_GLOBAL_LDLIBS += -pthread -lrt
TARGET_GLOBAL_LDLIBS_SHARED += -pthread -lrt
TARGET_GLOBAL_CFLAGS += -funwind-tables
