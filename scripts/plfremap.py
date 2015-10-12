#!/usr/bin/env python

import sys, os, logging
import optparse

from cStringIO import StringIO

import libplf

#===============================================================================
#===============================================================================
def getReMappedPath(pathMap, path):
	# Make sure given path starts with a '/'
	if not path.startswith("/"):
		path = "/" + path
	# Search in path map
	for entry in pathMap:
		if path.startswith(entry[0]):
			relPath = os.path.relpath(path, entry[0])
			if relPath == ".":
				return entry[1]
			else:
				return entry[1] + "/" + relPath
	# Not found
	logging.warning("No mapping found for %s", path)
	return path

#===============================================================================
#===============================================================================
def main():
	(options, args) = parseArgs()
	setupLog(options)

	plfFilePath = args[1]

	# Load path map
	pathMap = []
	pathMapFile = open(args[0])
	for line in pathMapFile:
		line = line.rstrip("\n").strip()
		if line and not line.startswith("#"):
			entry = line.split()
			if len(entry) != 2 and len(entry) != 3:
				logging.warning("%s: bad line: %s", args[0], line)
			else:
				pathMap.append(entry)
	pathMapFile.close()

	# Load plf
	plf = libplf.PlfFileInfo()
	plf.load(plfFilePath)

	# Process U_UNIXFILE entries, prepare a batch operation
	batchData = StringIO()
	for section in plf.sections:
		if section.type == "U_UNIXFILE":
			reMappedPath = getReMappedPath(pathMap, section.path).lstrip("/")
			logging.debug("%s -> %s", section.path, reMappedPath)
			batchData.write("'-j U_UNIXFILE:%d -p %s'\n" % 
					(section.idxSection, reMappedPath))
	libplf.plfbatchExec(plfFilePath, "'&'", batchData.getvalue())

	# Add path map roots at the start
	# We create a temp list that we reverse sort (because we will append each
	# item at the start of the plf). This way at the end directories will be
	# created in order
	dirPaths = []
	for entry in pathMap:
		# Only keep non-trivial entries
		if len(entry) >= 3 and entry[2] != "/":
			dirPaths.append(entry[2].lstrip("/"))
	dirPaths.sort(reverse=True)
	for dirPath in dirPaths:
		# We can't directly add our path because plftool checks first for its
		# existence. So add a fake . entry and rename it.
		logging.debug("Insert %s", dirPath)
		libplf.plftoolExec(["-j", "U_UNIXFILE:0",
				"-b", "U_UNIXFILE=.;mode=040755;uid=0;gid=0",
				"-j", "U_UNIXFILE:0",
				"-p", dirPath,
				plfFilePath])

#===============================================================================
# Setup option parser and parse command line.
#===============================================================================
def parseArgs():
	# Setup parser
	usage = "usage: %prog <path-map-file> <plf-file>"
	parser = optparse.OptionParser(usage=usage)

	parser.add_option("-q",
		dest="quiet",
		action="store_true",
		default=False,
		help="be quiet")
	parser.add_option("-v",
		dest="verbose",
		action="count",
		default=0,
		help="verbose output (more verbose if specified twice)")

	# Parse arguments and check validity
	(options, args) = parser.parse_args()
	if len(args) != 2:
		parser.error("Bad number of arguments")
	return (options, args)

#===============================================================================
# Setup logging system.
#===============================================================================
def setupLog(options):
	logging.basicConfig(
		level=logging.WARNING,
		format="[%(levelname)s] %(message)s",
		stream=sys.stderr)
	logging.addLevelName(logging.CRITICAL, "C")
	logging.addLevelName(logging.ERROR, "E")
	logging.addLevelName(logging.WARNING, "W")
	logging.addLevelName(logging.INFO, "I")
	logging.addLevelName(logging.DEBUG, "D")

	# setup log level
	if options.quiet == True:
		logging.getLogger().setLevel(logging.CRITICAL)
	elif options.verbose >= 2:
		logging.getLogger().setLevel(logging.DEBUG)
	elif options.verbose >= 1:
		logging.getLogger().setLevel(logging.INFO)

#===============================================================================
#===============================================================================
if __name__ == "__main__":
	main()
