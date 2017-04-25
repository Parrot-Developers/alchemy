###############################################################################
## @file toolchains/darwin/flags.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Additional flags for darwin toolchain.
###############################################################################

ifeq ("$(TARGET_OS_FLAVOUR)","native")

# Need to explicitely link C++ lib on MacOS
TARGET_GLOBAL_LDFLAGS += -lc++

endif

TARGET_GLOBAL_CFLAGS += $(APPLE_ARCH) $(APPLE_MINVERSION) -isysroot $(shell xcrun --sdk $(APPLE_SDK) --show-sdk-path)
TARGET_GLOBAL_LDFLAGS += $(APPLE_ARCH) $(APPLE_MINVERSION) -isysroot $(shell xcrun --sdk $(APPLE_SDK) --show-sdk-path)
