#!/bin/bash

SCRIPT_PATH=$(cd $(dirname $0) && pwd -P)

FILES=$1
MODULE_DIR=$2

# If no .clang-format file, skip formatting
CLANG_FORMAT_CFG=$(${SCRIPT_PATH}/find_clang_format.sh ${MODULE_DIR})
if [ -z "${CLANG_FORMAT_CFG}" ]; then
	echo "no .clang-format file found, nothing done"
	exit 0
fi

# From now, exec everything from the directory where CLANG_FORMAT_CFG is located
echo "found .clang-format file: ${CLANG_FORMAT_CFG}"
cd $(dirname ${CLANG_FORMAT_CFG})

# If no clang-format binary found, skip formatting
CLANG_FORMAT=$(${SCRIPT_PATH}/select_clang_format.sh)
if [ -z "${CLANG_FORMAT}" ]; then
	echo "clang-format not available, skip formatting"
	exit 0
fi

# If the clang-format file is not valid, skip formatting
CLANG_ERROR=$(${CLANG_FORMAT} -style=file -dump-config </dev/null 2>&1 >/dev/null)
if [ "${CLANG_ERROR}" ]; then
	echo ".clang-format file not valid with current clang-format binary, skip formatting"
	exit 0
fi

getperm ()
{
	# GNU find (findutils)
	find "$1" -printf "%m\n" 2>/dev/null && return

	# GNU stat (coreutils)
	stat -c "%#0a" "$1" 2>/dev/null && return

	# BSD stat
	stat -f "%#0Lp" "$1" 2>/dev/null && return

	echo "No suitable method found to retrieve octal permissions for $1" 1>&2
	exit 1
}

applyperm ()
{
	# GNU chmod (coreutils)
	chmod --reference "$1" "$2" 2>/dev/null && return

	# POSIX chmod
	chmod $(getperm "$1") "$2"
}

for FILE in ${FILES}; do
	NAME=$(basename ${FILE})
	TMP=$(mktemp -t ${NAME}.tmp.XXXXXX)
	${CLANG_FORMAT} -style=file --assume-filename=${NAME} <${FILE} >${TMP} || { rm "$TMP"; exit 1; }
	cmp -s ${FILE} ${TMP} && { rm "$TMP"; continue; }
	applyperm ${FILE} ${TMP} || { rm "$TMP"; exit 1; }
	mv ${TMP} ${FILE} || { rm "$TMP"; exit 1; }
done
