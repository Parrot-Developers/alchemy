###############################################################################
## @file classes/QMAKE/rules.mk
## @author Y.M. Morgan
## @date 2016/03/20
##
## Rules for QMAKE modules.
###############################################################################

# Find qmake binary
ifndef TARGET_QMAKE
  ifdef QTSDK_QMAKE
    # Compatibility
    $(warning Please use TARGET_QMAKE instead of QTSDK_QMAKE)
    TARGET_QMAKE := $(QTSDK_QMAKE)
  else ifeq ("$(TARGET_OS)-$(TARGET_OS_FLAVOUR)","$(HOST_OS)-native")
    TARGET_QMAKE := $(shell $(BUILD_SYSTEM)/scripts/findqmake.py \
      $(if $(TARGET_QT_VERSION),--version $(TARGET_QT_VERSION)) \
      $(if $(TARGET_QT_PLATFORM),--platform $(TARGET_QT_PLATFORM)) \
      $(if $(TARGET_QT_SDKROOT),--sdkroot $(TARGET_QT_SDKROOT)) \
      $(if $(TARGET_QT_SDK),--sdk $(TARGET_QT_SDK)) \
    )
  else
    TARGET_QMAKE := $(shell $(BUILD_SYSTEM)/scripts/findqmake.py --no-path \
      $(if $(TARGET_QT_VERSION),--version $(TARGET_QT_VERSION)) \
      $(if $(TARGET_QT_PLATFORM),--platform $(TARGET_QT_PLATFORM)) \
      $(if $(TARGET_QT_SDKROOT),--sdkroot $(TARGET_QT_SDKROOT)) \
      $(if $(TARGET_QT_SDK),--sdk $(TARGET_QT_SDK)) \
    )
  endif
  ifneq ("$(TARGET_QMAKE)","")
    $(info Using qmake: $(TARGET_QMAKE))
   endif
endif

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
  $(info $(LOCAL_MODULE): qmake not found)
  $(info TARGET_QT_VERSION=$(TARGET_QT_VERSION))
  $(info TARGET_QT_PLATFORM=$(TARGET_QT_PLATFORM))
  $(info TARGET_QT_SDKROOT=$(TARGET_QT_SDKROOT))
  $(info TARGET_QT_SDK=$(TARGET_QT_SDK))
  $(error $(LOCAL_MODULE): qmake not found)
endif

_module_msg := $(if $(_mode_host),Host )QMake

_module_def_cmd_configure := _qmake-def-cmd-configure
_module_def_cmd_build := _qmake-def-cmd-build
_module_def_cmd_install := _qmake-def-cmd-install
_module_def_cmd_clean := _qmake-def-cmd-clean

ifneq ("$(findstring -O0,$(LOCAL_CFLAGS))","")
  LOCAL_QMAKE_CONFIGURE_ARGS += CONFIG+=debug
else
  LOCAL_QMAKE_CONFIGURE_ARGS += CONFIG+=release
endif

_qmake_spec :=
ifeq ("$(TARGET_OS)-$(TARGET_OS_FLAVOUR)","linux-native")
  ifeq ("$(_module_cc_flavour)","gcc")
    _qmake_spec := linux-g++
  else ifeq ("$(_module_cc_flavour)","clang")
    _qmake_spec := linux-clang
  endif
endif
ifneq ("$(_qmake_spec)","")
  LOCAL_QMAKE_CONFIGURE_ARGS += -spec $(_qmake_spec)
endif

include $(BUILD_SYSTEM)/classes/GENERIC/rules.mk

# Restart configure if debug/release mode is changed
_qmake_configure_flags := $(_module_build_dir)/$(LOCAL_MODULE).configure.flags
$(_module_configured_stamp_file): $(_qmake_configure_flags)
$(_qmake_configure_flags): .FORCE
	@mkdir -p $(dir $@)
	@echo "$(PRIVATE_QMAKE_CONFIGURE_ARGS)" > $@.tmp
	$(call update-file-if-needed,$@,$@.tmp)

# Determine debug libraries of qmake dependencies
# Get the first word of LOCAL_EXPORT_LDLIBS and append '_debug'
_qmake_ldlibs_debug := $(LOCAL_LDLIBS)
ifeq ("$(TARGET_OS)","windows")
$(foreach __mod,$(all_external_libs), \
	$(if $(call streq,$(__modules.$(__mod).MODULE_CLASS),QMAKE), \
		$(eval __lib := $(firstword $(call module-get-export,$(__mod),LDLIBS))) \
		$(if $(__lib), \
			$(eval _qmake_ldlibs_debug := $(patsubst $(__lib),$(__lib)_debug,$(_qmake_ldlibs_debug))) \
		) \
	) \
)
endif

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
$(LOCAL_TARGETS): PRIVATE_LDLIBS_DEBUG := $(_qmake_ldlibs_debug)
$(LOCAL_TARGETS): PRIVATE_ALL_SHARED_LIBRARIES := $(all_shared_libs_filename)
$(LOCAL_TARGETS): PRIVATE_ALL_STATIC_LIBRARIES := $(all_static_libs_filename)
$(LOCAL_TARGETS): PRIVATE_ALL_WHOLE_STATIC_LIBRARIES := $(all_whole_static_libs_filename)
$(LOCAL_TARGETS): PRIVATE_ALCHEMY_PRI_FILE := $(_module_build_dir)/alchemy.pri
