###############################################################################
## @file warnings.mk
## @author Y.M. Morgan
## @date 2012/06/09
##
## Setup warning flags.
###############################################################################

# Internal use
WARNINGS_COMMON_FLAGS :=
WARNINGS_CFLAGS :=
WARNINGS_CFLAGS_gcc :=
WARNINGS_CFLAGS_clang :=
WARNINGS_CXXFLAGS :=
WARNINGS_CXXFLAGS_gcc :=
WARNINGS_CXXFLAGS_clang :=

# Externally overridable
WARNINGS_EXTRA_CFLAGS ?=
WARNINGS_EXTRA_CXXFLAGS ?=

# show option associated with warning (clang or gcc >= 4.0.0)
ifneq ("$(call check-version,$(TARGET_CC_VERSION),4.0.0)","")
  WARNINGS_COMMON_FLAGS_gcc += -fdiagnostics-show-option
endif

WARNINGS_COMMON_FLAGS_clang += -fdiagnostics-show-option

# colored diagnostics
#
# always been in clang, gcc since 4.9
ifeq ("$(USE_COLORS)","1")
  WARNINGS_COMMON_FLAGS_clang += -fcolor-diagnostics

# somehow they managed to use another option name than Clang's option
ifneq ("$(call check-version,$(TARGET_CC_VERSION),4.9.0)","")
ifneq ("$(call check-version,$(HOST_CC_VERSION),4.9.0)","")
  WARNINGS_COMMON_FLAGS_gcc += -fdiagnostics-color
endif
endif
endif

###############################################################################
## Common flags.
###############################################################################

WARNINGS_COMMON_FLAGS += -Wall
WARNINGS_COMMON_FLAGS += -Wextra
WARNINGS_COMMON_FLAGS += -Wno-unused -Wno-unused-parameter -Wunused-value -Wunused-variable -Wunused-label
WARNINGS_COMMON_FLAGS += -Wpointer-arith
WARNINGS_COMMON_FLAGS += -Wformat-nonliteral
WARNINGS_COMMON_FLAGS += -Wformat-security
WARNINGS_COMMON_FLAGS += -Winit-self

# Too many noise under ecos.
ifeq ("$(TARGET_OS)","ecos")
WARNINGS_COMMON_FLAGS += -Wno-format
endif

# android specifies -Wstrict-aliasing=2
# it generates too many false positive, use level 3 (default with -Wall or -Wstrict-aliasing)
 WARNINGS_COMMON_FLAGS_gcc += -Wstrict-aliasing=3

# Too many false positives with clang compiler
#  WARNINGS_COMMON_FLAGS_gcc += -Wcast-align

# clang or gcc >= 4.5.0 (too many false positives with previous versions)
  WARNINGS_COMMON_FLAGS_clang += -Wunreachable-code
ifneq ("$(call check-version,$(TARGET_CC_VERSION),4.5.0)","")
  WARNINGS_COMMON_FLAGS_gcc+= -Wunreachable-code
endif

# gcc >= 4.5.2
ifneq ("$(call check-version,$(TARGET_CC_VERSION),4.5.2)","")
  WARNINGS_COMMON_FLAGS_gcc += -Wlogical-op
endif

###############################################################################
## Specific flags.
###############################################################################

# C specific

WARNINGS_CFLAGS += -Wmissing-prototypes

# ecos forces it, remove it, not useful only problems found are :
# 'function declaration is not a prototype'
# if void is missing in function with no parameters
WARNINGS_CFLAGS += -Wno-strict-prototypes

# gcc >= 4.5.0
ifneq ("$(call check-version,$(TARGET_CC_VERSION),4.5.0)","")
  WARNINGS_CFLAGS_gcc += -Wjump-misses-init
endif

# c++ specific

# Too many warnings for the moment
#WARNINGS_CXXFLAGS += -Wctor-dtor-privacy
WARNINGS_CXXFLAGS += -Wno-ctor-dtor-privacy

# Too many warnings for the moment
#WARNINGS_CXXFLAGS += -Wnon-virtual-dtor
WARNINGS_CXXFLAGS += -Wno-non-virtual-dtor

WARNINGS_CXXFLAGS += -Wreorder
WARNINGS_CXXFLAGS += -Woverloaded-virtual

###############################################################################
## Extra warnings.
###############################################################################

ifeq ("$(W)","1")

# TODO: To be put back in W=0 mode
WARNINGS_COMMON_FLAGS += -Wshadow
WARNINGS_COMMON_FLAGS += -Wswitch-default
WARNINGS_COMMON_FLAGS += -Wwrite-strings
WARNINGS_COMMON_FLAGS += -Wundef
WARNINGS_CFLAGS += -Wmissing-declarations

# Possibly many false positives so only in W=1
WARNINGS_COMMON_FLAGS += -Wconversion
WARNINGS_COMMON_FLAGS += -Wswitch-enum
WARNINGS_COMMON_FLAGS += -Wcast-qual

# gcc >= 4.4.0
ifneq ("$(call check-version,$(TARGET_CC_VERSION),4.4.0)","")
  WARNINGS_COMMON_FLAGS_gcc += -Wframe-larger-than=1024
endif

endif

###############################################################################
## Add common flags to specific flags.
###############################################################################

WARNINGS_CFLAGS += $(WARNINGS_COMMON_FLAGS) $(WARNINGS_EXTRA_CFLAGS)
WARNINGS_CXXFLAGS += $(WARNINGS_COMMON_FLAGS) $(WARNINGS_EXTRA_CXXFLAGS)

WARNINGS_CFLAGS_gcc += $(WARNINGS_COMMON_FLAGS_gcc)
WARNINGS_CXXFLAGS_gcc += $(WARNINGS_COMMON_FLAGS_gcc)

WARNINGS_CFLAGS_clang += $(WARNINGS_COMMON_FLAGS_clang)
WARNINGS_CXXFLAGS_clang += $(WARNINGS_COMMON_FLAGS_clang)
