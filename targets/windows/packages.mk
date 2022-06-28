###############################################################################
## @file targets/windows/packages.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Additional packages for windows target.
###############################################################################

LOCAL_PATH := $(call my-dir)

$(call register-prebuilt-pkg-config-module-with-path,json,json-c,$(TARGET_PKG_CONFIG_PATH))
$(call register-prebuilt-pkg-config-module-with-path,libxml2,libxml-2.0,$(TARGET_PKG_CONFIG_PATH))
$(call register-prebuilt-pkg-config-module-with-path,sdl2,sdl2,$(TARGET_PKG_CONFIG_PATH))
$(call register-prebuilt-pkg-config-module-with-path,zlib,zlib,$(TARGET_PKG_CONFIG_PATH))
