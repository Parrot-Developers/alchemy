#!/bin/sh

usage()
{
	echo ""
	echo "Apply a set of patch files on a source tree."
	echo ""
	echo "Usage: $0 <targerdir> <patchdir> <patchfiles>..."
	echo "  <targerdir> : Target directory where to apply patches."
	echo "  <patchdir>  : Directory where to find path files."
	echo "  <patchfiles>: List of patch files to apply."
}

# Check arguments
if [ "$#" -lt "2" ]; then
	usage; exit 1
fi

# Get arguments
targetdir=$1
patchdir=$2
shift 2
patchfiles="$@"

# Check validity of given directories
if [ ! -d "${targetdir}" ] ; then
	echo "Aborting.  '${targetdir}' is not a directory."
	exit 1
fi
if [ ! -d "${patchdir}" ] ; then
	echo "Aborting.  '${patchdir}' is not a directory."
	exit 1
fi

# Process files
for f in ${patchfiles} ; do
	echo "Applying ${f}: "
	cat ${patchdir}/${f} | patch --binary -p1 -E -d ${targetdir}
	if [ "$?" != "0" ] ; then
		echo "Patch failed!  Please fix ${f}!"
		exit 1
	fi
done

# Check for rejects...
if [ "$(find ${targetdir}/ '(' -name '*.rej' -o -name '.*.rej' ')' -print)" ] ; then
	echo "Aborting.  Reject files found."
	exit 1
fi

# Remove backup files
find ${targetdir}/ '(' -name '*.orig' -o -name '.*.orig' ')' -exec rm -f {} \;
