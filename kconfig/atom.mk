###############################################################################
# kconfig makefile to build several tools to configure software.
#
###############################################################################

LOCAL_PATH := $(call my-dir)

###############################################################################
# parser
###############################################################################
include $(CLEAR_VARS)

LOCAL_MODULE := parser
PARSER_BUILD_DIR := $(call local-get-build-dir)
LOCAL_EXPORT_C_INCLUDES := $(LOCAL_PATH)/parser
LOCAL_EXPORT_CFLAGS := -DKBUILD_NO_NLS
LOCAL_SRC_FILES := parser/zconf.c

# Too many warning diue to gperf generated code
LOCAL_CFLAGS := -Wno-missing-field-initializers

LOCAL_PREREQUISITES := \
	$(PARSER_BUILD_DIR)/zconf.lex.c \
	$(PARSER_BUILD_DIR)/zconf.hash.c \
	$(PARSER_BUILD_DIR)/zconf.tab.c

$(PARSER_BUILD_DIR)/zconf.lex.c: $(LOCAL_PATH)/parser/zconf.l
	@mkdir -p $(dir $@)
	@echo "Generating zconf.lex.c"
	$(Q)flex --noline --prefix=zconf --outfile=$@ $<

$(PARSER_BUILD_DIR)/zconf.hash.c: $(LOCAL_PATH)/parser/zconf.gperf
	@mkdir -p $(dir $@)
	@echo "Generating zconf.hash.c"
	$(Q)gperf --readonly-tables --output-file=$@ $<

ifeq ("$(BISON_BIN)","")
  $(error 'bison' is required)
endif
$(PARSER_BUILD_DIR)/zconf.tab.c: $(LOCAL_PATH)/parser/zconf.y
	@mkdir -p $(dir $@)
	@echo "Generating zconf.tab.c"
	$(Q)$(BISON_BIN) --debug --no-lines --name-prefix=zconf --output=$@ $<

include $(BUILD_STATIC_LIBRARY)

###############################################################################
# lxdialog
###############################################################################
include $(CLEAR_VARS)

LOCAL_MODULE := lxdialog

LOCAL_EXPORT_C_INCLUDES := $(LOCAL_PATH)/lxdialog
LOCAL_EXPORT_CFLAGS := -DCURSES_LOC="<ncurses.h>" -DKBUILD_NO_NLS

LOCAL_SRC_FILES := \
	lxdialog/checklist.c \
	lxdialog/inputbox.c \
	lxdialog/menubox.c \
	lxdialog/textbox.c \
	lxdialog/util.c \
	lxdialog/yesno.c

LOCAL_LIBRARIES := ncurses

include $(BUILD_STATIC_LIBRARY)

###############################################################################
# conf
###############################################################################
include $(CLEAR_VARS)

LOCAL_MODULE := conf
LOCAL_SRC_FILES := conf.c
LOCAL_LIBRARIES := parser

include $(BUILD_EXECUTABLE)

###############################################################################
# mconf
###############################################################################
include $(CLEAR_VARS)

LOCAL_MODULE := mconf
LOCAL_LDLIBS := -lncurses
LOCAL_SRC_FILES := mconf.c
LOCAL_LIBRARIES := parser lxdialog

include $(BUILD_EXECUTABLE)

###############################################################################
# nconf
###############################################################################
ifneq ("$(TARGET_OS)","darwin")

include $(CLEAR_VARS)

LOCAL_MODULE := nconf
LOCAL_LDLIBS := -lmenu -lpanel -lncurses
LOCAL_SRC_FILES := nconf.c nconf.gui.c
LOCAL_LIBRARIES := parser ncurses
include $(BUILD_EXECUTABLE)

endif

###############################################################################
# qconf
###############################################################################
QCONF_PKG := Qt5Core Qt5Gui Qt5Widgets

ifeq ("$(TARGET_OS)","darwin")
  QCONF_PKG_CONFIG_PATH := /usr/local/opt/qt5/lib/pkgconfig
else
  QCONF_PKG_CONFIG_PATH :=
endif
QCONF_PKG_CONFIG := PKG_CONFIG_PATH=$(QCONF_PKG_CONFIG_PATH) pkg-config

ifeq ("$(shell $(QCONF_PKG_CONFIG) --exists $(QCONF_PKG); echo $$?)","0")

include $(CLEAR_VARS)

LOCAL_MODULE := qconf
QCONF_BUILD_DIR := $(call local-get-build-dir)
LOCAL_CFLAGS := $(shell $(QCONF_PKG_CONFIG) $(QCONF_PKG) --cflags)
LOCAL_LDLIBS := $(shell $(QCONF_PKG_CONFIG) $(QCONF_PKG) --libs)
LOCAL_SRC_FILES := qconf.cc
LOCAL_LIBRARIES := parser

ifeq ("$(TARGET_ARCH)","x86")
  LOCAL_CFLAGS += -fPIC
endif

QCONF_MOC := $(shell $(QCONF_PKG_CONFIG) Qt5Core --variable=host_bins)/moc
LOCAL_PREREQUISITES := $(QCONF_BUILD_DIR)/qconf.moc

# Too many warnings due to compat stuff
LOCAL_CFLAGS += -Wno-overloaded-virtual
LOCAL_CXXFLAGS += -std=c++11

$(QCONF_BUILD_DIR)/qconf.moc: qconf.h
	@mkdir -p $(dir $@)
	@echo "Generating qconf.moc"
	$(Q)$(QCONF_MOC) -i $< -o $@

include $(BUILD_EXECUTABLE)

endif
