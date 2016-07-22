###############################################################################
## @file targets/darwin/iphoneos/setup.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Setup variables for darwin/iphoneos target.
###############################################################################

TARGET_ARCH := arm
TARGET_DEFAULT_ARM_MODE := arm
TARGET_FORCE_STATIC := 1

TARGET_IPHONE_VERSION ?= 8.2
APPLE_SDK := iphoneos
APPLE_MINVERSION := -miphoneos-version-min=$(TARGET_IPHONE_VERSION)
