#!/bin/bash

SCRIPT_PATH=$(cd $(dirname $0) && pwd -P)

FILES=$1

GST_INDENT="${SCRIPT_PATH}/../codeformat/gst-indent.sh"

applyperm ()
{
	# GNU chmod (coreutils)
	chmod --reference "$1" "$2" 2>/dev/null && return

	# POSIX chmod
	chmod $(getperm "$1") "$2"
}

for FILE in ${FILES}; do
	NAME=$(basename ${FILE})
	TMP=$(mktemp ${FILE}.tmp.XXXXXX)
	$GST_INDENT ${FILE} ${TMP} || { rm "$TMP"; exit 1; }
	cmp -s ${FILE} ${TMP} && { rm "$TMP"; continue; }
	applyperm ${FILE} ${TMP} || { rm "$TMP"; exit 1; }
	mv ${TMP} ${FILE} || { rm "$TMP"; exit 1; }
done
