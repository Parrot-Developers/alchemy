#!/bin/bash

SCRIPT_PATH=$(cd $(dirname $0) && pwd -P)

FORMATTERS=$1
ARGS=$2
FILES=$3
MODULE_DIR=$4

for FORMATTER in ${FORMATTERS}; do
	if [ "${FORMATTER}" = "clang-format" ]; then
		${SCRIPT_PATH}/clang-format.sh "${FILES}" ${MODULE_DIR}
	elif [ "${FORMATTER}" = "gst" ]; then
		${SCRIPT_PATH}/gst-indent-format.sh "${FILES}"
	else
		echo "Unknown 'c' formatter '${FORMATTER}'"
	fi
done
