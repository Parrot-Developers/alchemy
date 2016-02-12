#!/bin/bash

# This script assumes it is copied in the staging or final dir
# Folders bin, usr/bin, lib, /usr/lib are subdirectories there
#
# If sourced, PATH and LD_LIBRARY_PATH are updated so programs can be executed
# from shell.
#
# If executed, first argument is the program to execute and remaining argumants
# are treated as the program argument.


# Get full path to this script (either when executed or sourced)
if [ -n "$ZSH_VERSION" ]; then
	# this line permits the script to be sourced from a ZSH shell
	SCRIPT_PATH=$(cd $(dirname ${(%):-%N}) && pwd)
else
	# assume Bash
	SCRIPT_PATH=$(cd $(dirname ${BASH_SOURCE}) && pwd)
fi

SYSROOT=${SCRIPT_PATH}

# Restore previous variables
if [ "${OLD_PATH}" != "" ]; then
	export PATH=${OLD_PATH}
fi
if [ "${OLD_LD_LIBRARY_PATH}" != "" ]; then
	export LD_LIBRARY_PATH=${OLD_LD_LIBRARY_PATH}
fi

# Save previous variables
OLD_PATH=${PATH}
OLD_LD_LIBRARY_PATH=${LD_LIBRARY_PATH}

# Update path
export PATH=${SYSROOT}/bin:${SYSROOT}/usr/bin:${PATH}

# Update library path
export LD_LIBRARY_PATH=${SYSROOT}/lib:${SYSROOT}/usr/lib:${LD_LIBRARY_PATH}

# execute given command line (only if not sourced)
if [ "${BASH_SOURCE}" = "$0" ]; then
	"$@"
fi

