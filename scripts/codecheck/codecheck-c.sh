#!/bin/bash

SCRIPT_PATH=$(cd $(dirname $0) && pwd -P)

CHECKER=$1
ARGS=$2
FILES=$3

if [ "${CHECKER}" = "linux" ]; then
	${SCRIPT_PATH}/checkpatch.pl \
		--no-tree --no-summary --terse --show-types -f \
		${ARGS} \
		${FILES}
else
	echo "Unknown 'c' checker '${CHECKER}'"
fi
