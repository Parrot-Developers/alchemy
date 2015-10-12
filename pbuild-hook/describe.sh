#!/bin/bash

if [ "$#" == "1" ]; then
	PATTERN="${1}*"
else
	PATTERN=""
fi

# try to get a CVS tag
if [ -f CVS/Tag ]; then
	TAG=$(cat CVS/Tag | sed -e 's/.//')
	printf "cvs-${TAG}"
	
# check for a git repository
elif head=$(git rev-parse --verify HEAD 2>/dev/null); then

	# Get current commit
	SHA1=$(git rev-parse HEAD 2>/dev/null)

	# This get all tags associated with a sha1
	#TAGS=$(git show-ref --tags -d 2>/dev/null | grep ^${SHA1} | sed -e 's,.* refs/tags/,,' -e 's/\^{}//')

	# Get first tag preceding the current commit, append -dirty if local changes exist
	if [ "${PATTERN}" == "" ]; then
		DESCRIBE=$(git describe --tags --dirty 2>/dev/null)
	else
		DESCRIBE=$(git describe --tags --match=${PATTERN} --dirty 2>/dev/null)
	fi

	# Print either tag description or sha1
	if [ "${DESCRIBE}" != "" ]; then
		printf "${DESCRIBE}"
	else
		# check dirty flag
		DIRTY=$(git diff-index --name-only HEAD 2>/dev/null)
		if [ "${DIRTY}" == "" ]; then
			printf "${SHA1}"
		else
			printf "${SHA1}-dirty"
		fi
	fi
fi
