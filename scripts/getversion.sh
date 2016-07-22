#!/bin/sh

# Is there a configure script ?
if [ -f configure ]; then
	version=$(grep "PACKAGE_VERSION=" configure)
	if [ "${version}" != "" ]; then
		version=$(echo ${version} | sed "s/PACKAGE_VERSION='\(.*\)'/\1/g")
	fi
fi

# Is this a linux module ?
if [ "$1" = "linux" -a -f Makefile ]; then
	major=$(grep "^VERSION = " Makefile | sed "s/VERSION = \(.*\)/\1/g")
	minor=$(grep "^PATCHLEVEL = " Makefile | sed "s/PATCHLEVEL = \(.*\)/\1/g")
	level=$(grep "^SUBLEVEL = " Makefile | sed "s/SUBLEVEL = \(.*\)/\1/g")
	version="${major}.${minor}.${level}"
fi

if [ "${version}" = "" ]; then
	version="unknown"
fi

echo ${version}
