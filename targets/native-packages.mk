###############################################################################
## @file targets/native-packages.mk
## @author Y.M. Morgan
## @date 2016/03/05
##
## Additional generic packages for native target.
###############################################################################

LOCAL_PATH := $(call my-dir)

$(call register-prebuilt-pkg-config-module,zlib,zlib)
$(call register-prebuilt-pkg-config-module,ncurses,ncurses)

# If ncurses not available via pkg-config, try harder...
ifeq ("$(call is-module-registered,ncurses)","")
  ifneq ("$(wildcard /usr/include/ncurses.h)","")
    include $(CLEAR_VARS)
    LOCAL_MODULE := ncurses
    LOCAL_EXPORT_LDLIBS := -lncurses
    $(call local-register-prebuilt-overridable)
  endif
endif
