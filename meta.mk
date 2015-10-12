###############################################################################
## @file meta.mk
## @author Y.M. Morgan
## @date 2014/12/07
##
## Handle modules using custom rules.
###############################################################################

# Set also LOCAL_MODULE so that everything works correctly
ifneq ("$(LOCAL_HOST_MODULE)","")
  LOCAL_MODULE := $(LOCAL_HOST_MODULE)
endif

LOCAL_MODULE_CLASS := META_PACKAGE

$(module-add)
