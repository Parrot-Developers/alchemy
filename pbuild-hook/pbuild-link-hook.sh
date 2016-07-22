#!/bin/sh

# Check argument count, do NOT display anything on stdout
if [ $# -lt 5 ]; then
	exit 0
fi

# Get parameters
NM=$1
CC=$2
MODULE_NAME=$3
OUT_DIR=$(dirname $4)
DEPS_DATA=$5
shift 5
OBJECTS="$@"

OUT_SRC=${OUT_DIR}/pbuild_link_hook.cpp
OUT_OBJ=${OUT_DIR}/pbuild_link_hook.o

# Reset the output files
mkdir -p ${OUT_DIR}
rm -f ${OUT_SRC}
rm -f ${OUT_OBJ}
touch ${OUT_SRC}

###############################################################################
## Write in output.
###############################################################################
outwrite()
{
	echo "$1" >> ${OUT_SRC}
}

###############################################################################
## Banner.
###############################################################################
outwrite "/*"
outwrite " * GENERATED FILE, DO NOT MODIFY"
outwrite " */"
outwrite ""

###############################################################################
## plog dynamic level.
###############################################################################

# List all symbols matching the pattern
PATTERN="pal_log_dyn_level_"
PATTERN_LEN=18

SYMBOLS=$( \
	${NM} -u ${OBJECTS} | \
	grep "U ${PATTERN}" | \
	awk '{ print $2}' | \
	sort | uniq --skip-chars=${PATTERN_LEN} \
)

if [ "${SYMBOLS}" != "" ]; then

	# Level definition shall be in extern "C" block
	outwrite "extern \"C\" {"
	outwrite ""

	# Shall be the same structure than in 'pbuild-stub.c'
	outwrite "struct pal_log_dyn_data {"
	outwrite "    int *level;"
	outwrite "    const char *ident;"
	outwrite "    struct pal_log_dyn_data *next;"
	outwrite "};"
	outwrite ""
	outwrite "void pal_log_dyn_add(struct pal_log_dyn_data *data);"
	outwrite ""

	# Define levels and data structure
	for x in ${SYMBOLS}; do
		outwrite "int ${x} = 3;"
		outwrite "static struct pal_log_dyn_data ${x}_data ="
		outwrite "    {&${x}, \"${x#pal_log_dyn_level_}\", 0};"
		outwrite ""
	done

	# End of extern "C" block
	outwrite "}"
	outwrite ""

	# Use a global class object in anonymous namespace to do load time registration
	outwrite "namespace {"
	outwrite ""

	# Start class declaration
	outwrite "class pal_log_dyn_init {"
	outwrite "public:"

	# Register levels in constructor
	outwrite "    pal_log_dyn_init() {"
	for x in ${SYMBOLS}; do
		outwrite "        pal_log_dyn_add(&${x}_data);"
	done
	outwrite "    }"

	# End of class declaration + global object
	outwrite "} pal_log_dyn_init_obj;"
	outwrite ""

	# End of anonymous namespace
	outwrite "}"
	outwrite ""

fi

###############################################################################
## Library describe
###############################################################################

if [ "${DEPS_DATA}" != "" ]; then
	# Definition shall be in extern "C" block
	outwrite "extern \"C\" {"
	outwrite ""

	# Shall be the same structure than in 'pbuild-stub.c'
	outwrite "struct pal_lib_desc_data {"
	outwrite "    const char *lib;"
	outwrite "    const char *desc;"
	outwrite "    struct pal_lib_desc_data *next;"
	outwrite "};"
	outwrite ""
	outwrite "void pal_lib_desc_add(struct pal_lib_desc_data *data);"
	outwrite ""

	# Data structure
	outwrite "static struct pal_lib_desc_data lib_desc_data[] = {"
	for x in ${DEPS_DATA}; do
		lib=$(echo "${x}" | cut -d: -f1)
		desc=$(echo "${x}" | cut -d: -f2)
		outwrite "    {\"${lib}\", \"${desc}\", 0},"
	done
	outwrite "    {0, 0, 0}"
	outwrite "};"

	# End of extern "C" block
	outwrite "}"
	outwrite ""

	# Use a global class object in anonymous namespace to do load time registration
	outwrite "namespace {"
	outwrite ""

	# Start class declaration
	outwrite "class pal_lib_desc_init {"
	outwrite "public:"

	# Register data in constructor
	outwrite "    pal_lib_desc_init() {"
	outwrite "        for (int i = 0; lib_desc_data[i].lib != 0; i++)"
	outwrite "            pal_lib_desc_add(&lib_desc_data[i]);"
	outwrite "    }"

	# End of class declaration + global object
	outwrite "} pal_lib_desc_init_obj;"
	outwrite ""

	# End of anonymous namespace
	outwrite "}"
	outwrite ""
fi

###############################################################################
## Final step.
###############################################################################

# Compile the file, generate the .o
${CC} -o ${OUT_OBJ} -c ${OUT_SRC}

# Print it so it will be added in the link
echo ${OUT_OBJ}
