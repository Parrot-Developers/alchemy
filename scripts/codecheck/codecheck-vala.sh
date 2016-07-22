#!/bin/bash

SCRIPT_PATH=$(cd $(dirname $0) && pwd -P)

CHECKER=$1
ARGS=$2
FILES=$3

if [ "${CHECKER}" = "valastyle" ]; then
	${SCRIPT_PATH}/checkvalastyle.pl \
		${ARGS} \
		${FILES}
else
	echo "Unknown 'vala' checker '${CHECKER}'"
fi
