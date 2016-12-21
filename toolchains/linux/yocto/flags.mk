###############################################################################
## @file toolchains/linux/yocto/flags.mk
## @author Y.M. Morgan
## @date 2016/12/02
##
## Additional flags for linux/yocto toolchain.
###############################################################################

# Assume everybody will want this
TARGET_GLOBAL_LDLIBS += -pthread -lrt
