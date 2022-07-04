#!/bin/bash

# Selected clang-format version can be forced by setting the
# ALCHEMY_CLANG_FORMAT_VERSION variable in the environment

if [ -z "${ALCHEMY_CLANG_FORMAT_VERSION}" ]; then
    ALCHEMY_CLANG_FORMAT_VERSION=11
fi

CLANG_FORMAT=$(basename "$(which clang-format-${ALCHEMY_CLANG_FORMAT_VERSION})")

if [ -z "${CLANG_FORMAT}" ]; then
    >&2 echo "Unable to find clang-format version ${ALCHEMY_CLANG_FORMAT_VERSION}"
fi

echo $CLANG_FORMAT
