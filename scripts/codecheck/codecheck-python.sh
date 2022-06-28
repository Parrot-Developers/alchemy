#!/bin/bash

SCRIPT_PATH=$(cd $(dirname $0) && pwd -P)

CHECKERS=$1
ARGS=$2
FILES=$3
MODULE_DIR=$4

for CHECKER in ${CHECKERS}; do
	if [ "${CHECKER}" = "pep8" ]; then
		python3 -m pycodestyle ${ARGS} ${FILES}
	elif [ "${CHECKER}" = "flake8" ]; then
		flake8 --format="%(path)s:%(row)d: WARNING:%(code)s: %(text)s" ${ARGS} ${FILES}
	else
		echo "Unknown 'python' checker '${CHECKER}'"
	fi
done
