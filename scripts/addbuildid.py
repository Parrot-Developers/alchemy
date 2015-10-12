#!/usr/bin/env python

import sys, os, logging
import stat
import subprocess
import optparse
import tempfile
import hashlib

import libelf

#===============================================================================
#===============================================================================

# Default values
DEFAULT_OBJCOPY = "objcopy"
DEFAULT_SECTION_NAME = ".alchemy.build-id"

# Extension to exclude (and that might be valid elf files)
EXCLUDE_FILTERS = [".a", ".ko", ".o"]

# Suffix for temp files
TEMP_SUFFIX = ".alchemy"

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
# Make sure we have write access a file.
# Some modules install binaries in read only mode preventing objcopy to add
# a section.
#===============================================================================
def fixWritePerm(filePath):
	mode = stat.S_IMODE(os.stat(filePath).st_mode)
	if (mode&stat.S_IWUSR) == 0:
		os.chmod(filePath, mode|stat.S_IWUSR)

#===============================================================================
#===============================================================================
def addBuildId(options, filePath, buildId):
	if options.dryRun:
		print("DRY RUN : Adding '%s' section : %s" % (options.sectionName, buildId))
	else:
		logging.info("-> Adding '%s' section : %s", options.sectionName, buildId)
	# Create a temp file with the content of the buildId (as text)
	(tempFd, tempPath) = tempfile.mkstemp(suffix=TEMP_SUFFIX)
	tempFile = os.fdopen(tempFd, "w")
	tempFile.write(buildId)
	tempFile.close()
	# Start objcopy to add the section
	args = [options.objcopy, "--add-section",
		 "%s=%s" % (options.sectionName, tempPath), filePath]
	if not options.dryRun:
		try:
			fixWritePerm(filePath)
			st = os.stat(filePath)
			process = subprocess.Popen(args)
			process.wait()
			# Restore dates (more precise that -p option of objcopy)
			# To make sure we don't put an older date due to truncation, add 2
			# micro-second to the times
			os.utime(filePath, (st.st_atime+0.000002, st.st_mtime+0.000002))
			if process.returncode != 0:
				logging.error("Failed to add '%s' section (err=%d) : %s",
						options.sectionName, process.returncode, filePath)
		except OSError as ex:
			logging.error("Failed to execute command: %s [err=%d %s]",
				" ".join(args), ex.errno, ex.strerror)
	# Cleaning
	os.unlink(tempPath)

#===============================================================================
#===============================================================================
def processFile(options, filePath):
	logging.info("Processing file : %s", filePath)
	elf = libelf.Elf()
	try:
		elf.loadFromFile(filePath)
		if not elf.hasSection(options.sectionName):
			buildId = elf.computeHash(hashlib.sha1()) # IGNORE:E1101
			addBuildId(options, filePath, buildId)
		else:
			logging.debug("-> '%s' section already present", options.sectionName)
		elf.close()
	except libelf.ElfError as ex:
		logging.error("%s : %s)", ex, filePath)

#===============================================================================
#===============================================================================
def processDir(options, rootDir):
	logging.info("Processing directory : %s", rootDir)
	for (dirPath, dirNames, fileNames) in os.walk(rootDir):
		for fileName in fileNames:
			filePath = os.path.join(dirPath, fileName)
			if os.path.islink(filePath) or not isElf(filePath):
				continue
			if os.path.splitext(filePath)[1] in EXCLUDE_FILTERS:
				logging.debug("Exclude file : %s", filePath) 
				continue
			processFile(options, filePath)

#===============================================================================
#===============================================================================
def main():
	(options, args) = parseArgs()
	setupLog(options)

	# Process arguments
	for arg in args:
		if os.path.isdir(arg):
			processDir(options, arg)
		elif os.path.isfile(arg):
			if not isElf(arg):
				logging.error("File is not a valid elf file : %s", arg)
			else:
				processFile(options, arg)

#===============================================================================
# Setup option parser and parse command line.
#===============================================================================
def parseArgs():
	usage = "usage: %prog [options] <dir>|<file>..."
	parser = optparse.OptionParser(usage = usage)
	parser.add_option("--objcopy",
		dest="objcopy",
		default=DEFAULT_OBJCOPY,
		help="objcopy program to use to add section (default: '%s')" % DEFAULT_OBJCOPY)
	parser.add_option("--section-name",
		dest="sectionName",
		default=DEFAULT_SECTION_NAME,
		help="name of section to add (default: '%s')" % DEFAULT_SECTION_NAME)
	parser.add_option("-n",
		dest="dryRun",
		action="store_true",
		default=False,
		help="do not execute anything, just print")

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
