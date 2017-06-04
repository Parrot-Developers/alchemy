###############################################################################
## @file classes/genproject-rules.mk
## @author M. Girard
## @date 2018/05/20
##
## Rules for genproject.
###############################################################################

# Generate rules
.PHONY: $(LOCAL_MODULE)-genproject
$(foreach ide,$(genproject-get-ides),$(eval $(call _genproject-gen-rules,$(ide))))
