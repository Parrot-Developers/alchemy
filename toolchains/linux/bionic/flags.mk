###############################################################################
## @file toolchains/linux/bionic/flags.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Additional flags for linux/bionic toolchain.
###############################################################################

ifndef USE_ALCHEMY_ANDROID_SDK

ifeq ("$(TARGET_ANDROID_SHARED_STL)","1")
  ifeq ("$(TARGET_ANDROID_STL)","gnustl")
    TARGET_GLOBAL_LDFLAGS += -lgnustl_shared
  else ifeq ("$(TARGET_ANDROID_STL)","libc++")
    TARGET_GLOBAL_LDFLAGS += -lc++_shared
  else ifeq ("$(TARGET_ANDROID_STL)","stlport")
    TARGET_GLOBAL_LDFLAGS += -lstlport_shared
  endif
endif

# Needed by some modules
TARGET_GLOBAL_CFLAGS += -DANDROID -DANDROID_NDK

else

TARGET_GLOBAL_C_INCLUDES += \
	$(BUILD_SYSTEM)/toolchains/linux/bionic/include

endif

TARGET_GLOBAL_LDFLAGS += -Wl,-O1
