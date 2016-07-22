#!/bin/sh

set -e

SCRIPT_PATH=$(cd $(dirname $0) && pwd -P)

# Determine ALCHEMY_HOME
if [ "${ALCHEMY_HOME}" = "" ]; then
	export ALCHEMY_HOME=${SCRIPT_PATH}/..
fi
readonly ALCHEMAKE=${ALCHEMY_HOME}/scripts/alchemake

# Setup minimal variables
export ALCHEMY_WORKSPACE_DIR=$(pwd)
export ALCHEMY_TARGET_CONFIG_DIR=$(pwd)/config
export ALCHEMY_TARGET_OUT=$(pwd)/out
export ALCHEMY_TARGET_SDK_DIRS=$(cd $(pwd)/sdk && pwd -P)

# Generate a full config
rm -f ${ALCHEMY_TARGET_CONFIG_DIR}/global.config
${ALCHEMAKE} config-force-all config-update

# Go !
${ALCHEMAKE} "$@"
