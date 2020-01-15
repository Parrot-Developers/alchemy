###############################################################################
## @file classes/codecheck-rules.mk
## @author Y.M. Morgan
## @date 2016/06/12
##
## Rules for codecheck.
###############################################################################

# Recursive wildcard
# $1 base directory
# $2 pattern
rwildcard = $(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2) $(filter $(subst *,%,$2),$d))

# Original data before import
_module_src_files := $(addprefix $(LOCAL_PATH)/,$(__modules.$(LOCAL_MODULE).SRC_FILES))
_module_c_includes := $(__modules.$(LOCAL_MODULE).C_INCLUDES)
_module_c_includes += $(LOCAL_PATH)
_module_exported_includes := $(__modules.$(LOCAL_MODULE).EXPORT_C_INCLUDES)

# Search for include files in directories with source files
_module_c_includes += $(sort $(foreach __src,$(_module_src_files),$(dir $(__src))))
_module_c_includes := $(sort $(abspath $(_module_c_includes)))

# Codecheck for asm files
_codecheck_as_files := $(filter %.s,$(_module_src_files))
_codecheck_as_files += $(filter %.S,$(_module_src_files))

# Codecheck for c files
_codecheck_c_files := $(filter %.c,$(_module_src_files))
_codecheck_c_files += $(foreach __inc,$(_module_c_includes),$(wildcard $(__inc)/*.h))
_codecheck_c_files += $(foreach __inc,$(_module_exported_includes),$(call rwildcard, $(__inc)/, *.h))

# Codecheck for c++ files
_codecheck_cxx_files := $(filter %.cpp,$(_module_src_files))
_codecheck_cxx_files += $(filter %.cc,$(_module_src_files))
_codecheck_cxx_files += $(filter %.cxx,$(_module_src_files))
_codecheck_cxx_files += $(foreach __inc,$(_module_c_includes),$(wildcard $(__inc)/*.hpp))
_codecheck_cxx_files += $(foreach __inc,$(_module_c_includes),$(wildcard $(__inc)/*.hh))
_codecheck_cxx_files += $(foreach __inc,$(_module_c_includes),$(wildcard $(__inc)/*.hxx))
_codecheck_cxx_files += $(foreach __inc,$(_module_exported_includes),$(call rwildcard, $(__inc)/, *.hpp))
_codecheck_cxx_files += $(foreach __inc,$(_module_exported_includes),$(call rwildcard, $(__inc)/, *.hh))
_codecheck_cxx_files += $(foreach __inc,$(_module_exported_includes),$(call rwildcard, $(__inc)/, *.hxx))

# Codecheck for objc files
_codecheck_objc_files := $(filter %.m,$(_module_src_files))
_codecheck_objcpp_files := $(filter %.mm,$(_module_src_files))

# Codecheck for vala files
_codecheck_vala_files := $(filter %.vala,$(_module_src_files))

# Codecheck for python files
_codecheck_python_files := $(filter %.py,$(_module_src_files))

# Sort to have unique names
_codecheck_as_files := $(sort $(_codecheck_as_files))
_codecheck_c_files := $(sort $(_codecheck_c_files))
_codecheck_cxx_files := $(sort $(_codecheck_cxx_files))
_codecheck_objc_files := $(sort $(_codecheck_objc_files))
_codecheck_objcpp_files := $(sort $(_codecheck_objcpp_files))
_codecheck_vala_files := $(sort $(_codecheck_vala_files))
_codecheck_python_files := $(sort $(_codecheck_python_files))

# Ignore some defect when using linux checker but for code outside the kernel
ifneq ($(filter linux,$(call _codecheck-get-checker,c,C)),)
ifneq ("$(LOCAL_MODULE_CLASS)","LINUX")
ifneq ("$(LOCAL_MODULE_CLASS)","LINUX_MODULE")
LOCAL_CODECHECK_C_ARGS += --ignore SPLIT_STRING,PREFER_ALIGNED,PREFER_PACKED
endif
endif
endif

# Generate rules
.PHONY: $(LOCAL_MODULE)-codecheck
$(eval $(call _codecheck-gen-rules,as,AS))
$(eval $(call _codecheck-gen-rules,c,C))
$(eval $(call _codecheck-gen-rules,cxx,CXX))
$(eval $(call _codecheck-gen-rules,objc,OBJC))
$(eval $(call _codecheck-gen-rules,vala,VALA))
$(eval $(call _codecheck-gen-rules,python,PYTHON))
