#!/bin/sh

usage()
{
	echo ""
	echo "Apply a set of sed files to a config."
	echo ""
	echo "usage: $0 [-v] <input> <output> <sedfiles>..."
	echo "  -v        : Activate verbose mode."
	echo "  <input>   : Original config file."
	echo "  <output>  : Output config file."
	echo "  <sedfiles>: List of sed files to apply."
}

# Activate verbose mode
if [ "$1" = "-v" ]; then
	readonly VERBOSE=1
	shift
else
	readonly VERBOSE=0
fi

# Check arguments
if [ "$#" -lt "2" ]; then
	usage; exit 1
fi

# Get arguments
readonly CONFIG_IN_FILE=$1
readonly CONFIG_OUT_FILE=$2
shift 2

# Do the operation in a temp file
readonly CONFIG_OUT_FILE_TMP=$(mktemp -t tmp.XXXXXXXXXX)

# Log something if verbose mode is activated
logv()
{
	if [ "${VERBOSE}" != "0" ]; then
		echo "$@" >&2
	fi
}

# First, copy original file
cp -f ${CONFIG_IN_FILE} ${CONFIG_OUT_FILE_TMP}

# Apply sed files
for f in "$@"; do
	logv "Apply $f on ${CONFIG_IN_FILE} to ${CONFIG_OUT_FILE}"
	sed --file=$f -i.bak ${CONFIG_OUT_FILE_TMP}
	rm -f ${CONFIG_OUT_FILE_TMP}.bak
done

# Move in final place if needed
mkdir -p $(dirname ${CONFIG_OUT_FILE})
if ! test -f ${CONFIG_OUT_FILE} ; then
	# Output does not exist
	logv "Output does not exist"
	mv -f ${CONFIG_OUT_FILE_TMP} ${CONFIG_OUT_FILE}
elif ! cmp ${CONFIG_OUT_FILE_TMP} ${CONFIG_OUT_FILE} >/dev/null 2>&1 ; then
	# Output has changed since last time
	logv "Output has changed"
	mv -f ${CONFIG_OUT_FILE_TMP} ${CONFIG_OUT_FILE}
else
	# Cleanup
	logv "Output is the same"
	rm -f ${CONFIG_OUT_FILE_TMP}
fi
