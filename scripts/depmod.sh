#!/bin/sh

DEPMOD=/sbin/depmod

if [ "${LINUX_DEPMOD_LOCKFILE}" = "" ]; then
	echo "Missing LINUX_DEPMOD_LOCKFILE in environment"
	exit 1
fi

exec flock --wait 60 ${LINUX_DEPMOD_LOCKFILE} ${DEPMOD} "$@"
