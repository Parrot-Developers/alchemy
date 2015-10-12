#!/bin/bash

# This script assumes it is copied in the staging or final dir
# Folders bin, usr/bin, lib, /usr/lib are subdirectories there
# 
# If sourced, PATH and DYLD_LIBRARY_PATH are updated so programs can be executed
# from shell.
#
# If executed, first argument is the program to execute and remaining argumants
# are treated as the program argument.


# Get full path to this script (either when executed or sourced)
SCRIPT_PATH=$(cd $(dirname ${BASH_SOURCE}) && pwd)
SYSROOT=${SCRIPT_PATH}

# Restore previous variables
if [ "${OLD_PATH}" != "" ]; then
	export PATH=${OLD_PATH}
fi
if [ "${OLD_DYLD_LIBRARY_PATH}" != "" ]; then
	export DYLD_LIBRARY_PATH=${OLD_DYLD_LIBRARY_PATH}
fi

# Save previous variables
OLD_PATH=${PATH}
OLD_DYLD_LIBRARY_PATH=${DYLD_LIBRARY_PATH}

# Update path
export PATH=${SYSROOT}/bin:${SYSROOT}/usr/bin:${PATH}

# Update library path
export DYLD_LIBRARY_PATH=${SYSROOT}/lib:${SYSROOT}/usr/lib:${DYLD_LIBRARY_PATH}

# execute given command line (only if not sourced)
if [ "${BASH_SOURCE}" = "$0" ]; then
	"$@"
fi

