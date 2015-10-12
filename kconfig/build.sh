#!/bin/bash -e

# Autodetect target os
export TARGET_OS=$(uname -s | awk '{print tolower($$0)}')

# Autodetect target architecture
if [ "${TARGET_ARCH}" = "" ]; then
	dummy=$(gcc -dumpmachine | grep 64)
	if [ "$?" == "0" ]; then
		export TARGET_ARCH=x64
	else
		export TARGET_ARCH=x86
	fi
fi

# Expor some settings
export TARGET_OUT=out-${TARGET_OS}-${TARGET_ARCH}
export TARGET_OUT_BUILD=${TARGET_OUT}/build
export TARGET_OUT_STAGING=${TARGET_OUT}/staging
export TARGET_OUT_FINAL=bin-${TARGET_OS}-${TARGET_ARCH}

# Execute makefile
if [ "$1" = "clean" ]; then
	make -f ../main.mk clean
elif [ "$1" = "clobber" ]; then
	make -f ../main.mk clobber
	rm -rf ${TARGET_OUT}
else
	make -f ../main.mk all
	make -f ../main.mk final
	rm -f ${TARGET_OUT_FINAL}/native-wrapper.sh
fi

