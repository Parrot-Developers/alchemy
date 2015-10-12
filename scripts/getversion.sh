#!/bin/bash

# Is there a configure script ?
if [ -f configure ]; then
	version=$(grep "PACKAGE_VERSION=" configure)
	if [ "${version}" != "" ]; then
		version=$(echo ${version} | sed "s/PACKAGE_VERSION='\(.*\)'/\1/g")
	fi
fi

if [ "${version}" = "" ]; then
	version="unknown"
fi

echo ${version}
