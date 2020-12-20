#!/bin/bash

lookup_6_or_higher ()
{
    # Find oldest clang-format available
    OLD_IFS=$IFS
    IFS=":"

    find ${PATH} -name 'clang-format-*' 2>/dev/null | grep -oE '[0-9]+(\.[0-9]+)*)?$' | sort -V | uniq | while read v ; do

	if test $(expr "$v" '>=' '6.0') -ne 0 ; then
	    echo "clang-format-$v"
	    break
	fi
    done

    IFS=$OLD_IFS
}

lookup_default ()
{
    basename "$(which clang-format)"
}

CLANG_FORMAT=$(lookup_6_or_higher)

if test "x$CLANG_FORMAT" = "x"; then
    CLANG_FORMAT=$(lookup_default)
fi

echo $CLANG_FORMAT
