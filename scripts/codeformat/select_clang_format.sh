#!/bin/bash

SCRIPT_PATH=$(cd $(dirname $0) && pwd -P)

# Find newest clang-format available
OLD_IFS=$IFS
IFS=":"
CLANG_FORMAT=$(ls ${PATH} 2>/dev/null | grep -E '^clang-format(-[0-9]\.[0-9])?$' | sort -r | head -n1)
IFS=$OLD_IFS

echo ${CLANG_FORMAT}
