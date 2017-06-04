#!/bin/bash

SCRIPT_PATH=$(cd $(dirname $0) && pwd -P)

CHECKERS=$1
ARGS=$2
FILES=$3
MODULE_DIR=$4

for CHECKER in ${CHECKERS}; do
	if [ "${CHECKER}" = "cpplint" ]; then
		${SCRIPT_PATH}/cpplint.py \
			--extension cpp,cxx,cc,hpp,hxx,hh --counting detailed --verbose 0 \
			${ARGS} \
			${FILES}
	elif [ "${CHECKER}" = "clang-format" ]; then
		${SCRIPT_PATH}/clang-format-check.sh "${FILES}" ${MODULE_DIR}
	else
		echo "Unknown 'cxx' checker '${CHECKER}'"
	fi
done
