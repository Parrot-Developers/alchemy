###############################################################################
## @file classes/codeformat-rules.mk
## @author N. Brulez
## @date 2018/11/16
##
## Rules for code formatting.
###############################################################################

# Use codecheck source lists
_codeformat_c_files := $(_codecheck_c_files)
_codeformat_cxx_files := $(_codecheck_cxx_files)
_codeformat_objc_files := $(_codecheck_objc_files)
_codeformat_objcpp_files := $(_codecheck_objcpp_files)
_codeformat_python_files := $(_codecheck_python_files)

# Generate rules
.PHONY: $(LOCAL_MODULE)-codeformat
$(eval $(call _codeformat-gen-rules,c,C))
$(eval $(call _codeformat-gen-rules,cxx,CXX))
$(eval $(call _codeformat-gen-rules,objc,OBJC))
$(eval $(call _codeformat-gen-rules,python,PYTHON))
