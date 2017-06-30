###############################################################################
## @file toolchains/flags.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Setup toolchain variables.
###############################################################################

###############################################################################
# Initialize host global variables.
###############################################################################

HOST_GLOBAL_C_INCLUDES ?=
HOST_GLOBAL_ASFLAGS ?=
HOST_GLOBAL_CFLAGS ?=
HOST_GLOBAL_CXXFLAGS ?=
HOST_GLOBAL_OBJCFLAGS ?=
HOST_GLOBAL_VALAFLAGS ?=
HOST_GLOBAL_ARFLAGS ?=
HOST_GLOBAL_LDFLAGS ?=
HOST_GLOBAL_LDLIBS ?=

HOST_GLOBAL_CFLAGS_gcc ?=
HOST_GLOBAL_CFLAGS_clang ?=
HOST_GLOBAL_CXXFLAGS_gcc ?=
HOST_GLOBAL_CXXFLAGS_clang ?=
HOST_GLOBAL_LDFLAGS_gcc ?=
HOST_GLOBAL_LDFLAGS_clang ?=

HOST_GLOBAL_PCHFLAGS ?= -x c++-header

###############################################################################
# Initialize target global variables.
###############################################################################

TARGET_GLOBAL_C_INCLUDES ?=
TARGET_GLOBAL_ASFLAGS ?=
TARGET_GLOBAL_CFLAGS ?=
TARGET_GLOBAL_CXXFLAGS ?=
TARGET_GLOBAL_OBJCFLAGS ?=
TARGET_GLOBAL_NVCFLAGS ?=
TARGET_GLOBAL_VALAFLAGS ?=
TARGET_GLOBAL_ARFLAGS ?=
TARGET_GLOBAL_LDFLAGS ?=
TARGET_GLOBAL_LDLIBS ?=

TARGET_GLOBAL_CFLAGS_gcc ?=
TARGET_GLOBAL_CFLAGS_clang ?=
TARGET_GLOBAL_CXXFLAGS_gcc ?=
TARGET_GLOBAL_CXXFLAGS_clang ?=
TARGET_GLOBAL_LDFLAGS_gcc ?=
TARGET_GLOBAL_LDFLAGS_clang ?=

TARGET_GLOBAL_PCHFLAGS ?= -x c++-header

###############################################################################
## Generic setup.
###############################################################################

# Add some host generic flags
HOST_GLOBAL_CFLAGS += -pipe -O2 -g0
HOST_GLOBAL_LDFLAGS += -O2
HOST_GLOBAL_ARFLAGS += rcs

# Add some target generic flags
TARGET_GLOBAL_CFLAGS += -pipe -O2 -g
TARGET_GLOBAL_LDFLAGS += -O2
TARGET_GLOBAL_ARFLAGS += rcs

# -ffunction-sections is not compatible with clang's -fembed-bitcode
ifeq ("$(filter -fembed-bitcode,$(TARGET_GLOBAL_CFLAGS))","")
  TARGET_GLOBAL_CFLAGS += -ffunction-sections
endif

ifeq ("$(TARGET_USE_CXX_EXCEPTIONS)","0")
  TARGET_GLOBAL_CXXFLAGS += -fno-exceptions
endif

# Notify that build is performed by alchemy
HOST_GLOBAL_CFLAGS += -DALCHEMY_BUILD
TARGET_GLOBAL_CFLAGS += -DALCHEMY_BUILD

# Don't emit warning for unused driver arguments
HOST_GLOBAL_CFLAGS_clang += -Qunused-arguments
TARGET_GLOBAL_CFLAGS_clang += -Qunused-arguments

# Enable ARC for all ObjC builds
HOST_GLOBAL_OBJCFLAGS += -fobjc-arc
TARGET_GLOBAL_OBJCFLAGS += -fobjc-arc

# TODO : get this based on real version of valac and glib used.
TARGET_GLOBAL_VALAFLAGS += \
	--vapidir=$(HOST_OUT_STAGING)/$(HOST_ROOT_DESTDIR)/share/vala-0.20/vapi \
	$(foreach __dir,$(TARGET_OUT_STAGING) $(TARGET_SDK_DIRS), \
		--vapidir=$(__dir)/$(TARGET_ROOT_DESTDIR)/share/vala/vapi \
	) \
	--target-glib=2.36

###############################################################################
## Specific setup.
###############################################################################
-include $(BUILD_SYSTEM)/toolchains/cpu.mk
-include $(BUILD_SYSTEM)/toolchains/flags-$(TARGET_ARCH).mk
-include $(BUILD_SYSTEM)/toolchains/$(TARGET_OS)/flags.mk

# Just to avoid using undefined variable for arch other than arm
HOST_GLOBAL_CFLAGS_$(HOST_ARCH) ?=
HOST_GLOBAL_LDFLAGS_$(HOST_ARCH) ?=
TARGET_GLOBAL_CFLAGS_$(TARGET_ARCH) ?=
TARGET_GLOBAL_LDFLAGS_$(TARGET_ARCH) ?=

TARGET_CPU_ARMV7A_NEON ?= 0
TARGET_CPU_HAS_NEON ?= 0
TARGET_CPU_HAS_SSE ?= 0
TARGET_CPU_HAS_SSE2 ?= 0
TARGET_CPU_HAS_SSSE3 ?= 0

ifeq ("$(HOST_ARCH)","x86")
  HOST_GLOBAL_CFLAGS += -m32
  HOST_GLOBAL_LDFLAGS += -m32
else ifeq ("$(HOST_ARCH)","x64")
  HOST_GLOBAL_CFLAGS += -m64 -fPIC
  HOST_GLOBAL_LDFLAGS += -m64
endif
