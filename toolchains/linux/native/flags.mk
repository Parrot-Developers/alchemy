###############################################################################
## @file toolchains/linux/native/flags.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Additional flags for linux/native toolchain.
###############################################################################

# Assume everybody will want this
TARGET_GLOBAL_LDLIBS += -pthread -lrt
