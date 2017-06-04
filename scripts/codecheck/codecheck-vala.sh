#!/bin/bash

SCRIPT_PATH=$(cd $(dirname $0) && pwd -P)

CHECKERS=$1
ARGS=$2
FILES=$3

for CHECKER in ${CHECKERS}; do
	if [ "${CHECKER}" = "valastyle" ]; then
		${SCRIPT_PATH}/checkvalastyle.pl \
			${ARGS} \
			${FILES}
	else
		echo "Unknown 'vala' checker '${CHECKER}'"
	fi
done
