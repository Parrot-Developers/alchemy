#!/bin/sh

# This script assumes it is copied in the staging or final dir
# Folders bin, usr/bin, lib, /usr/lib are subdirectories there
#
# If sourced, PATH and LD_LIBRARY_PATH are updated so programs can be executed
# from shell.
#
# If executed, first argument is the program to execute and remaining arguments
# are treated as the program argument.

# Determine if the current script is sourced or executed
# https://stackoverflow.com/questions/2683279/how-to-detect-if-a-script-is-being-sourced
sourced=0
SCRIPT_NAME=
if [ -n "${ZSH_EVAL_CONTEXT-}" ]; then
	case ${ZSH_EVAL_CONTEXT} in
		*:file)
			sourced=1
			SCRIPT_NAME=$0
		;;
	esac
elif [ -n "${KSH_VERSION-}" ]; then
	if [ "$(cd $(dirname -- $0) && pwd -P)/$(basename -- $0)" != "$(cd $(dirname -- ${.sh.file}) && pwd -P)/$(basename -- ${.sh.file})" ]; then
		sourced=1
		SCRIPT_NAME=${.sh.file}
	fi
elif [ -n "${BASH_VERSION-}" ]; then
	if (return 0 2>/dev/null); then
		sourced=1
		SCRIPT_NAME=${BASH_SOURCE}
	fi
else
	# All other shells: examine $0 for known shell binary filenames
	# Detects `sh` and `dash`; add additional shell filenames as needed.
	case ${0##*/} in
		sh|dash)
			sourced=1
		;;
	esac
fi

# Get full path to this script (either when executed or sourced)
if [ "${sourced}" = "1" ]; then
	if [ -z "${SCRIPT_NAME}" ]; then
		echo "Unsupported shell"
		SCRIPT_PATH=
	else
		SCRIPT_PATH=$(cd $(dirname -- ${SCRIPT_NAME}) >/dev/null && pwd -P)
	fi
else
	SCRIPT_PATH=$(cd $(dirname -- $0) >/dev/null && pwd -P)
fi

export SYSROOT=${SCRIPT_PATH}

# Determine if we are under Darwin (to use DYLD_LIBRARY_PATH instead of LD_LIBRARY_PATH
is_darwin=0
if [ "$(uname -s)" = "Darwin" ]; then
	is_darwin=1
fi

# Restore previous variables
if [ "${OLD_PATH-}" != "" ]; then
	PATH=${OLD_PATH}
fi
if [ "${OLD_LIBRARY_PATH-}" != "" ]; then
	LIBRARY_PATH=${OLD_LIBRARY_PATH}
fi

# Save previous variables
OLD_PATH=${PATH}
if [ "${is_darwin}" = "0" ]; then
	OLD_LIBRARY_PATH=${LD_LIBRARY_PATH-}
else
	OLD_LIBRARY_PATH=${DYLD_LIBRARY_PATH-}
fi

# Update path
PATH=${SYSROOT}/bin:${SYSROOT}/usr/bin:${OLD_PATH}

# Update library path
LIBRARY_PATH=${SYSROOT}/lib:${SYSROOT}/usr/lib:${OLD_LIBRARY_PATH}

# Update python path
PYTHONPATH=${SYSROOT}/usr/lib/python/site-packages

export PATH=${PATH}
if [ "${is_darwin}" = "0" ]; then
	export LD_LIBRARY_PATH=${LIBRARY_PATH}
else
	export DYLD_LIBRARY_PATH=${LIBRARY_PATH}
fi
if [ -d $PYTHONPATH ]; then
	export PYTHONPATH=${PYTHONPATH}
fi

# Execute given command line (only if not sourced)
if [ "${sourced}" = "0" ]; then
	exec "$@"
fi
