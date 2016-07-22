#!/bin/sh

set -e

SCRIPT_PATH=$(cd $(dirname $0) && pwd -P)

export ALCHEMY_HOME=${SCRIPT_PATH}/..
export ALCHEMY_WORKSPACE_DIR=${SCRIPT_PATH}

HOST_OS=$(${ALCHEMY_HOME}/scripts/host.py OS)
HOST_ARCH=$(${ALCHEMY_HOME}/scripts/host.py ARCH)

# Use gmake under bsd
if [ "${MAKE}" = "" ]; then
	case ${HOST_OS} in
		*bsd*)
			export MAKE=gmake
		;;
	esac
fi

# Autodetect target os/arch
export TARGET_OS=${HOST_OS}
export TARGET_OS_FLAVOUR=native
if [ "${TARGET_ARCH}" = "" ]; then
	export TARGET_ARCH=${HOST_ARCH}
fi
export TARGET_OUT=${SCRIPT_PATH}/out/${TARGET_OS}-${TARGET_ARCH}
export TARGET_DEFAULT_ARM_MODE=arm

# Execute makefile
if [ "$1" = "" ]; then
	${ALCHEMY_HOME}/scripts/alchemake all final
	mkdir -p bin-${TARGET_OS}-${TARGET_ARCH}
	cp -af ${TARGET_OUT}/final/usr/bin/*conf* bin-${TARGET_OS}-${TARGET_ARCH}
elif [ "$1" = "clean" ]; then
	${ALCHEMY_HOME}/scripts/alchemake "$@"
	rm -rf ${TARGET_OUT}
else
	${ALCHEMY_HOME}/scripts/alchemake "$@"
fi
