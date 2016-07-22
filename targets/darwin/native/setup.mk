###############################################################################
## @file targets/darwin/native/setup.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Setup variables for darwin/native target.
###############################################################################

TARGET_ARCH ?= $(HOST_ARCH)

TARGET_MACOS_VERSION ?= 10.10
APPLE_SDK := macosx
APPLE_MINVERSION := -mmacosx-version-min=$(TARGET_MACOS_VERSION)
