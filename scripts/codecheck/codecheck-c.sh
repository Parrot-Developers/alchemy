#!/bin/bash

SCRIPT_PATH=$(cd $(dirname $0) && pwd -P)

CHECKERS=$1
ARGS=$2
FILES=$3
MODULE_DIR=$4

for CHECKER in ${CHECKERS}; do
	if [ "${CHECKER}" = "linux" ]; then
		${SCRIPT_PATH}/checkpatch.pl \
			--no-tree --no-summary --terse --show-types -f \
			${ARGS} \
			${FILES}
	elif [ "${CHECKER}" = "clang-format" ]; then
		${SCRIPT_PATH}/clang-format-check.sh "${FILES}" ${MODULE_DIR}
	elif [ "${CHECKER}" = "gst" ]; then
		${SCRIPT_PATH}/gst-indent-check.sh "${FILES}" ${MODULE_DIR}
	else
		echo "Unknown 'c' checker '${CHECKER}'"
	fi
done
