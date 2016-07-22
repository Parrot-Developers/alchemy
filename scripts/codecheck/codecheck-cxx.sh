#!/bin/bash

SCRIPT_PATH=$(cd $(dirname $0) && pwd -P)

CHECKER=$1
ARGS=$2
FILES=$3

if [ "${CHECKER}" = "cpplint" ]; then
	${SCRIPT_PATH}/cpplint.py \
		--extension cpp,cxx,cc,hpp,hxx,hh --counting detailed --verbose 0 \
		${ARGS} \
		${FILES}
else
	echo "Unknown 'cxx' checker '${CHECKER}'"
fi
