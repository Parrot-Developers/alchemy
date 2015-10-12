#!/usr/bin/env python

import sys, os, logging
import optparse

import libelf

#===============================================================================
#===============================================================================
class Context(object):
	def __init__(self):
		self.binaries = {}
		self.libraries = {}

#===============================================================================
# Determine if a file is an elf file.
#===============================================================================
def isElf(filePath):
	result = False
	try:
		file = open(filePath, "rb")
		header = str(file.read(4))
		if header.find("ELF") >= 0:
			result = True
		file.close()
	except IOError as ex:
		logging.error("Failed to open file: %s ([err=%d] %s)",
			filePath, ex.errno, ex.strerror)
	return result

#===============================================================================
#===============================================================================
def processFile(ctx, filePath):
	logging.info("Processing file : %s", filePath)
	elf = libelf.Elf()
	try:
		elf.loadFromFile(filePath)
		libraries = []
		for dynEntry in elf.dynamicEntries:
			if dynEntry.d_tag == libelf.DT_NEEDED \
					and dynEntry.valstr not in libraries:
				libraries.append(dynEntry.valstr)
			if dynEntry.d_tag == libelf.DT_RPATH:
				logging.warning("%s: uses DT_RPATH '%s'",
						filePath, dynEntry.valstr)
		ctx.binaries[filePath] = libraries
		for lib in libraries:
			if lib not in ctx.libraries:
				ctx.libraries[lib] = False
		elf.close()
	except libelf.ElfError as ex:
		logging.error("%s: %s)", filePath, ex)

#===============================================================================
#===============================================================================
def main():
	(options, args) = parseArgs()
	setupLog(options)

	ctx = Context()
	if not args:
		rootDir = os.getcwd()
	else:
		rootDir = args[0]

	# Process all ELF files in given root directory
	for (dirPath, dirNames, fileNames) in os.walk(rootDir):
		for excludeDir in ["proc", "sys", "dev"]:
			if excludeDir in dirNames:
				dirNames.remove(excludeDir)
		for fileName in fileNames:
			filePath = os.path.join(dirPath, fileName)
			if os.path.islink(filePath) or not isElf(filePath):
				continue
			processFile(ctx, filePath)

	# Determine missing libraries
	for (dirPath, dirNames, fileNames) in os.walk(rootDir):
		for fileName in fileNames:
			if fileName in ctx.libraries:
				ctx.libraries[fileName] = True

	# Print result
	for lib in ctx.libraries:
		if not ctx.libraries[lib]:
			# Only display the first binary that needs the library
			neededBy = None
			for bin in ctx.binaries:
				if lib in ctx.binaries[bin]:
					neededBy = bin
					break
			logging.warning("Missing library: '%s' needed by %s", lib, neededBy)

#===============================================================================
# Setup option parser and parse command line.
#===============================================================================
def parseArgs():
	usage = "usage: %prog [options] [<dir>]"
	parser = optparse.OptionParser(usage = usage)

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

	(options, args) = parser.parse_args()
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
# Entry point.
#===============================================================================
if __name__ == "__main__":
	main()
