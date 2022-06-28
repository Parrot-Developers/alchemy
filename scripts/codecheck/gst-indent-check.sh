#!/bin/bash

SCRIPT_PATH=$(cd $(dirname $0) && pwd -P)

FILES=$1

GST_INDENT="${SCRIPT_PATH}/../codeformat/gst-indent.sh"

for FILE in ${FILES}; do
	NAME=$(basename ${FILE})
	TMP=$(mktemp ${FILE}.tmp.XXXXXX)
	$GST_INDENT ${FILE} ${TMP} || { rm "$TMP"; exit 1; }
	diff -y --suppress-common-lines ${FILE} ${TMP}
	if [ $? -ne 0 ]; then
		echo "${FILE}:1: WARNING:GST-INDENT: wrong format"
	fi
	rm ${TMP}
done
