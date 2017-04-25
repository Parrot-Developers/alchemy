###############################################################################
## @file classes/QMAKE/rules.mk
## @author Y.M. Morgan
## @date 2016/03/20
##
## Rules for QMAKE modules.
###############################################################################

ifdef QT5_QMAKE
  QMAKE := $(QT5_QMAKE)
  _qmake_has_qt_sysroot := $(true)
else ifdef QT4_QMAKE
  QMAKE := $(QT4_QMAKE)
  _qmake_has_qt_sysroot := $(false)
else ifdef TARGET_QMAKE
  QMAKE := $(TARGET_QMAKE)
  _qmake_has_qt_sysroot := $(false)
else
  QMAKE :=
endif

ifeq ("$(QMAKE)","")
  $(error $(LOCAL_MODULE): qmake not found, add Qt4/Qt5 alchemy package or specify Qt SDK path via TARGET_QT_SDKROOT or TARGET_QT_SDK.)
endif

_module_msg := $(if $(_mode_host),Host )QMake

_module_def_cmd_configure := _qmake-def-cmd-configure
_module_def_cmd_build := _qmake-def-cmd-build
_module_def_cmd_install := _qmake-def-cmd-install
_module_def_cmd_clean := _qmake-def-cmd-clean

ifneq ("$(findstring -O0,$(LOCAL_CFLAGS))","")
  LOCAL_QMAKE_CONFIGURE_ARGS += CONFIG+=debug
endif

include $(BUILD_SYSTEM)/classes/GENERIC/rules.mk

$(LOCAL_TARGETS): PRIVATE_HAS_QT_SYSROOT := $(_qmake_has_qt_sysroot)
$(LOCAL_TARGETS): PRIVATE_QMAKE := $(QMAKE)
$(LOCAL_TARGETS): PRIVATE_QMAKE_PRO_FILE := $(LOCAL_QMAKE_PRO_FILE)
$(LOCAL_TARGETS): PRIVATE_QMAKE_CONFIGURE_ARGS := $(LOCAL_QMAKE_CONFIGURE_ARGS)
$(LOCAL_TARGETS): PRIVATE_QMAKE_MAKE_BUILD_ARGS := $(LOCAL_QMAKE_MAKE_BUILD_ARGS)
$(LOCAL_TARGETS): PRIVATE_QMAKE_MAKE_INSTALL_ARGS := $(LOCAL_QMAKE_MAKE_INSTALL_ARGS)
$(LOCAL_TARGETS): PRIVATE_C_INCLUDES := $(LOCAL_C_INCLUDES)
$(LOCAL_TARGETS): PRIVATE_CFLAGS := $(LOCAL_CFLAGS)
$(LOCAL_TARGETS): PRIVATE_CXXFLAGS := $(LOCAL_CXXFLAGS)
$(LOCAL_TARGETS): PRIVATE_LDFLAGS := $(LOCAL_LDFLAGS)
$(LOCAL_TARGETS): PRIVATE_LDLIBS := $(LOCAL_LDLIBS)
$(LOCAL_TARGETS): PRIVATE_ALL_SHARED_LIBRARIES := $(all_shared_libs_filename)
$(LOCAL_TARGETS): PRIVATE_ALL_STATIC_LIBRARIES := $(all_static_libs_filename)
$(LOCAL_TARGETS): PRIVATE_ALL_WHOLE_STATIC_LIBRARIES := $(all_whole_static_libs_filename)
$(LOCAL_TARGETS): PRIVATE_ALCHEMY_PRI_FILE := $(_module_build_dir)/alchemy.pri
