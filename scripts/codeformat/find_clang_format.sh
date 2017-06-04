#!/bin/bash

SCRIPT_PATH=$(cd $(dirname $0) && pwd -P)

MODULE_DIR=$1

# Exec everything from MODULE_DIR
cd ${MODULE_DIR}

# Search .clang-format file in MODULE_DIR or its parents, up to the
# git repository root
GITROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ "${GITROOT}" ]; then
	TESTDIR=${MODULE_DIR}
	while true; do
		CLANG_FORMAT_CFG=${TESTDIR}/.clang-format
		if [ -f "${CLANG_FORMAT_CFG}" ]; then
			break
		fi
		if [ "${TESTDIR}" = "${GITROOT}" ]; then
			break
		fi
		TESTDIR=$(dirname ${TESTDIR})
	done
else
	CLANG_FORMAT_CFG=${MODULE_DIR}/.clang-format
fi

if [ -f ${CLANG_FORMAT_CFG} ]; then
	echo ${CLANG_FORMAT_CFG}
fi
