#!/usr/bin/env python
#
# @file makefinal.py
# @author Y.M. Morgan
# @date 2012/07/09
#
# Generate the final directory by copying files from staging directory
#
# It also incorporate skeletons.
#
# It takes care of resolving links relative to final dir when copying files
# to avoid surprises...

import sys, os, logging
import platform
import subprocess
import optparse
import re
import fnmatch

import addbuildid

#===============================================================================
# Global variables.
#===============================================================================

# Available modes
MODE_FIRWMARE = "firmware"
MODE_FULL = "full"
MODE_DEFAULT = MODE_FIRWMARE
MODES = [MODE_FIRWMARE, MODE_FULL]

# Directories to always exclude
EXCLUDE_DIRS_ALWAYS = [".git", ".repo", "linux-headers", "linux-sdk"]

# Directories to exclude depending on mode
EXCLUDE_DIRS = {
	MODE_FIRWMARE: EXCLUDE_DIRS_ALWAYS + [
		"include", "vapi",
		"man", "doc", "html", "info",
		"pkgconfig", "cmake",
		"aclocal", "locale"
	],
	MODE_FULL: EXCLUDE_DIRS_ALWAYS
}

# Files to always exclude
EXCLUDE_FILES_ALWAYS = [
	".gitignore",
	"THIS_IS_NOT_THE_DIRECTORY_FOR_NATIVE_CHROOT",
	"vmlinux"]

# Files to exclude depending on mode
EXCLUDE_FILES = {
	MODE_FIRWMARE: EXCLUDE_FILES_ALWAYS,
	MODE_FULL: EXCLUDE_FILES_ALWAYS,
}

# Patterns to always exclude
EXCLUDE_FILTERS_ALWAYS = []

# Patterns to exclude depending on mode
EXCLUDE_FILTERS = {
	MODE_FIRWMARE: EXCLUDE_FILTERS_ALWAYS + [".a", ".la"],
	MODE_FULL: EXCLUDE_FILTERS_ALWAYS
}

EXCLUDE_FILTERS_PYTHON = [".py", ".pyc", ".pyo"]

# Linux folders/links
LINUX_BASIC_SKEL = [
	["dev", None],
	["home", None],
	["proc", None],
	["sys", None],
	["tmp", None],
	["lib/modules", None],
]

#==============================================================================
#==============================================================================
class CopyType(object):
	(ONLY_LINKS, NO_LINKS, ALL) = range(0, 3)

#==============================================================================
#==============================================================================
class Makefile(object):
	def __init__(self, fout):
		self.fout = fout
		self.rules = {}

	def addCopyCmd(self, dstFileName, srcFileName, doStrip):
		# Overwrite existing
		if dstFileName in self.rules:
			logging.debug("Overwrite %s: %s -> %s", dstFileName,
					self.rules[dstFileName][1], srcFileName)
		self.rules[dstFileName] = (dstFileName, srcFileName, doStrip)

	# Makefile banner
	# The .SUFFIXES is important to remove all implicit rules.
	# There is one which is really, really nasty :
	#   a file x is updated from a file x.sh automatically
	# Guess what happen when you have both in a folder :
	#  the executable is replaced by the script if older...
	def _writeHeader(self):
		self.fout.write("# GENERATED FILE, DO NOT MODIFY\n\n")
		# turns off suffix rules built into make
		self.fout.write(".SUFFIXES:\n")
		# turns off the RCS / SCCS implicit rules of GNU Make
		self.fout.write("%: RCS/%,v\n")
		self.fout.write("%: RCS/%\n")
		self.fout.write("%: %,v\n")
		self.fout.write("%: s.%\n")
		self.fout.write("%: SCCS/s.%\n")
		# other defines
		self.fout.write("ALL :=\n")
		self.fout.write("V ?= 0\n")
		self.fout.write("ifeq (\"$(V)\",\"0\")\n")
		self.fout.write("  PRINT =\n")
		self.fout.write("else\n")
		self.fout.write("  PRINT = @echo $1\n")
		self.fout.write("endif\n")
		self.fout.write(".PHONY: all\n")
		self.fout.write("all: do-all\n\n")

	# Makefile footer.
	def _writeFooter(self):
		self.fout.write(".PHONY: do-all\n")
		self.fout.write("do-all: $(ALL)\n\n")

	def write(self, options):
		self._writeHeader()
		idx = 0
		for rule in self.rules.values():
			(dstFileName, srcFileName, doStrip) = rule

			# use a generic target name to avoid issue with file names containing
			# special characters
			self.fout.write("ALL += file%d\n" % idx)
			self.fout.write(".PHONY: file%d\n" % idx)
			self.fout.write("file%d:\n" % idx)
			idx += 1

			# commands, see doCopy for more info
			cmds = getCopyCmds(dstFileName, srcFileName, options, doStrip)
			self.fout.write("\t$(call PRINT,\"Alchemy install: %s\")\n" %
					os.path.relpath(dstFileName))
			for cmd in cmds:
				self.fout.write("\t@%s\n" % cmd.replace("$", "$$"))
			self.fout.write("\n")
		self._writeFooter()

#==============================================================================
# Execute a command and get its output
#==============================================================================
def executeCmd(cmd):
	p = subprocess.Popen(cmd, stdout=subprocess.PIPE, shell = True)
	return p.communicate()[0].rstrip("\n").split("\n")

#===============================================================================
# Determine if a file is an executable.
#===============================================================================
def isExec(filePath):
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
# Determine if a file can be stripped.
# Required under android because soslim crashes when trying to strip
# static executables compiled with eglibc.
#===============================================================================
def canStrip(filePath):
	result = False
	try:
		# get error output from nm command to check for 'no symbols'
		p = subprocess.Popen("nm %s" % filePath,
			stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell = True)
		res = p.communicate()[1].rstrip("\n").split("\n")
		result = (len(res) == 0 or res[0].find("no symbols") < 0)
	except IOError as ex:
		# assume not strippable if nm failed
		result = False
	return result

#===============================================================================
# Resolve links using finalDir as root for absolute path.
#
# Taken from os.path._resolve_link
#===============================================================================
def resolveLink(finalDir, path):
	pathSeen = set()
	while os.path.islink(path):
		if path in pathSeen:
			# Already seen this path, so we must have a symlink loop
			return None
		pathSeen.add(path)
		# Resolve where the link points to
		resolved = os.readlink(path)
		if not os.path.isabs(resolved):
			dir = os.path.dirname(path)
			path = os.path.normpath(os.path.join(dir, resolved))
		elif resolved[0] == "/":
			# Remove leading '/' and join with final dir
			path = os.path.normpath(os.path.join(finalDir, resolved[1:]))
		else:
			# Absolute path not starting with '/' ???
			return None
	return path

#===============================================================================
# Get the realpath of a file by processing links relative to finalDir in case
# they points to absolute path
#
# Taken from os.path.realpath
#
# Note : the last level of link is not resolved as it can be the one we want to
# create and it already exist.
#===============================================================================
def getRealPath(finalDir, path):
	# First, make it absolute
	if not os.path.isabs(path):
		path = os.path.join(finalDir, path)
	bits = ["/"] + path.split("/")[1:]

	for i in range(2, len(bits)):
		component = os.path.join(*bits[0:i])
		# Resolve symbolic links.
		if os.path.islink(component):
			resolved = resolveLink(finalDir, component)
			if resolved is None:
				# Infinite loop -- return original component + rest of the path
				return os.path.abspath(os.path.join(*([component] + bits[i:])))
			else:
				return getRealPath(finalDir, os.path.join(*([resolved] + bits[i:])))

	return os.path.abspath(path)

#===============================================================================
#===============================================================================
def addBuildId(filePath, options):
	class AddBuildIdOptions(object):
		def __init__(self):
			if filePath.endswith(".ko") and options.buildIdObjcopyKernel != None:
				self.objcopy = options.buildIdObjcopyKernel
			else:
				self.objcopy = options.buildIdObjcopy
			self.sectionName = options.buildIdSectionName
			self.dryRun = False
	# Only if really required by options
	if not options.buildId:
		return
	if not addbuildid.isElf(filePath):
		return
	addbuildid.processFile(AddBuildIdOptions(), filePath)

#===============================================================================
# Get the commands to be executed for the copy.
#===============================================================================
def getCopyCmds(dstFileName, srcFileName, options, doStrip=False):
	cmds = []
	if not doStrip:
		# Simple copy
		cmds.append("cp -af \"%s\" \"%s\"" % (srcFileName, dstFileName))
	else:
		if doStrip:
			if srcFileName.endswith(".ko") and options.stripKernel != None:
				cmds.append("%s -o \"%s\" \"%s\"" % \
					(options.stripKernel, dstFileName, srcFileName))
			else:
				cmds.append("%s -o \"%s\" \"%s\"" % \
					(options.strip, dstFileName, srcFileName))
		# Restore mode and timestamp
		if platform.system().lower() == 'darwin':
			statCmd = 'stat -f \'%p\''
		else:
			statCmd = 'stat --printf \'%a\''
		cmds.append("chmod $(%s \"%s\") \"%s\"" % \
			(statCmd, srcFileName, dstFileName))
		cmds.append("touch -r \"%s\" \"%s\"" % \
			(srcFileName, dstFileName))
	if options.removeWGO and not os.path.islink(srcFileName):
		cmds.append("chmod g-w,o-w \"%s\"" % dstFileName)
	return cmds

#===============================================================================
# Copy a file using a makefile (to do strip in parallel).
#===============================================================================
def doCopyByMakefile(dstFileName, srcFileName, options, doStrip=False):
	options.makefile.addCopyCmd(dstFileName, srcFileName, doStrip)

#===============================================================================
# Copy a file by directly making a copy.
#===============================================================================
def doCopyDirect(dstFileName, srcFileName, options, doStrip=False):
	cmds = getCopyCmds(dstFileName, srcFileName, options, doStrip)
	for cmd in cmds:
		logging.debug("  %s", cmd)
		os.system(cmd)

#===============================================================================
#===============================================================================
def addPathInFileList(relPath, isDir, options):
	# Nothing to do it option not given
	if options.fileListFile == None:
		return

	# Make sure all path leading to this one is logged
	parts = relPath.split("/")[:-1]
	for i in range(0, len(parts)):
		parentDir = "/".join(parts[0:i])
		if parentDir != "" and parentDir not in options.fileListDirs:
			options.fileListDirs.append(parentDir)
			options.fileListFile.write("%s/\n" % parentDir)

	if isDir:
		if relPath not in options.fileListDirs:
			options.fileListDirs.append(relPath)
		relPath += "/"
	options.fileListFile.write("%s\n" % relPath)

#===============================================================================
# Copy a file/link.
#===============================================================================
def doCopy(dstFileName, srcFileName, options, forceCopy=False):
	relPath = os.path.relpath(dstFileName, options.finalDir)

	# do we need to strip ?
	doStrip = False
	if options.strip != None \
		and not os.path.islink(srcFileName) \
		and isExec(srcFileName) \
		and canStrip(srcFileName):
		doStrip = True

	# If the file to be stripped is in usr/lib/debug, simply skip it
	if doStrip and relPath.startswith("usr/lib/debug"):
		return

	addPathInFileList(relPath, False, options)

	# check strip filter
	if doStrip and options.reStripFilters:
		for reStripFilter in options.reStripFilters:
			if reStripFilter.match(os.path.basename(srcFileName)):
				logging.debug("Not stripping: %s", relPath)
				doStrip = False

	# check if we need to do something, do not follow symlinks
	doAction = forceCopy
	if not os.path.lexists(dstFileName):
		doAction = True
	elif not os.path.islink(srcFileName):
		if os.path.islink(dstFileName):
			logging.warning("Unable to overwrite symlink '%s' with file '%s'",
				dstFileName, srcFileName)
			return
		srcStat = os.stat(srcFileName)
		dstStat = os.stat(dstFileName)
		if srcStat.st_mtime > dstStat.st_mtime:
			doAction = True

	# nothing to do if destination is already OK
	if doAction == False:
		return
	if os.path.islink(srcFileName):
		logging.info("Link : %s", relPath)
	else:
		logging.info("File : %s", relPath)

	# make sure destination directory exists
	dstDirName = os.path.split(dstFileName)[0]
	if not os.path.lexists(dstDirName):
		os.makedirs(dstDirName, 0755)

	# do the copy by wanted method (always process links directly)
	if options.makefile != None and not os.path.islink(srcFileName):
		doCopyByMakefile(dstFileName, srcFileName, options, doStrip)
	else:
		doCopyDirect(dstFileName, srcFileName, options, doStrip)

#===============================================================================
# Process a directory and copy dirs/files to final directory.
#===============================================================================
def processDir(rootDir, options, withEmptyDir, copyType, forceCopy=False):
	for (dirPath, dirNames, fileNames) in os.walk(rootDir):
		# a symlink to an existing directory is put in dirNames, not fileNames
		# fix this (use a copy in for loop because we will modify dirNames)
		for dirName in dirNames[:]:
			if os.path.islink(os.path.join(dirPath, dirName)):
				dirNames.remove(dirName)
				fileNames.append(dirName)

		# exclude some directories
		# (use a copy in for loop because we will modify dirNames)
		for dirName in dirNames[:]:
			if any([fnmatch.fnmatch(dirName, pattern)
						for pattern in EXCLUDE_DIRS[options.mode]]):
				logging.debug("Exclude directory : %s",
					os.path.relpath(os.path.join(dirPath, dirName), rootDir))
				dirNames.remove(dirName)

		# create directories (useful for empty directories)
		if withEmptyDir:
			for dirName in dirNames:
				srcDirName = os.path.join(dirPath, dirName)
				relPath = os.path.relpath(srcDirName, rootDir)
				dstDirName = getRealPath(options.finalDir, relPath)
				addPathInFileList(relPath, True, options)
				if not os.path.lexists(dstDirName):
					logging.info("Directory : %s", relPath)
					os.makedirs(dstDirName, 0755)

		# copy files
		for fileName in fileNames:
			if any([fnmatch.fnmatch(fileName, pattern)
						for pattern in EXCLUDE_FILES[options.mode]]):
				logging.debug("Exclude file : %s",
					os.path.relpath(os.path.join(dirPath, fileName), rootDir))
				continue
			# skip some extensions
			srcFileName = os.path.join(dirPath, fileName)
			relPath = os.path.relpath(srcFileName, rootDir)
			if os.path.splitext(srcFileName)[1] in EXCLUDE_FILTERS[options.mode]:
				logging.debug("Exclude file : %s", relPath)
				continue

			# go
			if copyType == CopyType.ALL \
				or (copyType == CopyType.NO_LINKS and not os.path.islink(srcFileName)) \
				or (copyType == CopyType.ONLY_LINKS and os.path.islink(srcFileName)):
				dstFileName = getRealPath(options.finalDir, relPath)
				if not os.path.islink(srcFileName):
					addBuildId(srcFileName, options)
				doCopy(dstFileName, srcFileName, options, forceCopy=forceCopy)

#===============================================================================
# Process linux basic skel.
#===============================================================================
def processLinuxBasicSkel(options):
	for entry in LINUX_BASIC_SKEL:
		if entry[1] == None:
			dstDirName = getRealPath(options.finalDir, entry[0])
			if not os.path.lexists(dstDirName):
				logging.info("Directory : %s", entry[0])
				os.makedirs(dstDirName, 0755)
		else:
			dstLnkName = getRealPath(options.finalDir, entry[0])
			logging.info("Link : %s", entry[0])
			os.system("ln -sf \"%s\" \"%s\"" % (entry[1], dstLnkName))

#===============================================================================
# Main function.
#===============================================================================
def main():
	(options, args) = parseArgs()
	setupLog(options)

	# get parameters
	options.stagingDir = args[0]
	options.finalDir = os.path.realpath(args[1])
	logging.info("staging-dir : %s", options.stagingDir)
	logging.info("final-dir : %s", options.finalDir)

	# do we need to output a makefile ?
	options.makefile = None
	if len(args) >= 3:
		logging.info("makefile : %s", args[2])
		try:
			options.makefile = Makefile(open(args[2], "w"))
		except IOError as ex:
			logging.error("Failed to create file: %s [err=%d %s]",
					args[2], ex.errno, ex.strerror)

	# check mode
	if options.mode not in MODES:
		logging.error("Invalid mode '%s'. Available: %s", options.mode,
			", ".join(MODES))
		sys.exit(1)

	# update filter
	if options.mode != MODE_FULL and not options.keepPythonFiles:
		EXCLUDE_FILTERS[options.mode].extend(EXCLUDE_FILTERS_PYTHON)

	# filelist file
	options.fileListFile = None
	options.fileListDirs = []
	if options.fileListPath != None:
		try:
			options.fileListFile = open(options.fileListPath, "w")
		except IOError as ex:
			logging.error("Failed to create file: %s [err=%d %s]",
					options.fileListPath, ex.errno, ex.strerror)

	# regex for strip filters
	options.reStripFilters = []
	for stripFilter in options.stripFilters:
		stripFilter = stripFilter.replace(r".", r"\.")
		stripFilter = stripFilter.replace(r"*", r".*")
		options.reStripFilters.append(re.compile(stripFilter))

	# check that staging directory exists
	if not os.path.isdir(options.stagingDir):
		logging.error("%s is not a directory", options.stagingDir)

	# process links of skeleton directory (with empty dirs and links)
	for skelDir in options.skelDirs:
		processDir(skelDir, options, True, CopyType.ONLY_LINKS)

	# process staging directory (without empty dirs and with all files)
	processDir(options.stagingDir, options, False, CopyType.ALL)

	# process skeleton directory (without empty dirs and without links)
	# Force copy of file (always overwrite)
	for skelDir in options.skelDirs:
		processDir(skelDir, options, False, CopyType.NO_LINKS, forceCopy=True)

	# process linux basic skel
	if options.linuxBasicSkel:
		processLinuxBasicSkel(options)

	if options.makefile != None:
		options.makefile.write(options)
		options.makefile.fout.close()

#===============================================================================
# Setup option parser and parse command line.
#===============================================================================
def parseArgs():
	usage = "usage: %prog [options] <staging-dir> <final-dir> [<makefile>]"
	parser = optparse.OptionParser(usage = usage)
	parser.add_option("--strip",
		dest="strip",
		default=None,
		help="strip program to use to remove symbols")
	parser.add_option("--strip-kernel",
		dest="stripKernel",
		default=None,
		help="strip program to use to remove symbols from kernel modules")
	parser.add_option("--skel",
		dest="skelDirs",
		default=[],
		action="append",
		help="path to skeleton tree to merge in final tree")
	parser.add_option("--linux-basic-skel",
		dest="linuxBasicSkel",
		action="store_true",
		default=False,
		help="Create a basic linux skel (proc, dev, tmp...)")
	parser.add_option("--strip-filter",
		dest="stripFilters",
		default=[],
		action="append",
		help="Filter of file names that will no be stripped (ex: ld-*.so)")
	parser.add_option("--remove-wgo",
		dest="removeWGO",
		action="store_true",
		default=False,
		help="Remove write access for group and other on all copied files")
	parser.add_option("--build-id",
		dest="buildId",
		action="store_true",
		default=None,
		help="Add a build id section in executables and shared libraries")
	parser.add_option("--build-id-objcopy",
		dest="buildIdObjcopy",
		default=None,
		help="objcopy program to use to add build id section")
	parser.add_option("--build-id-objcopy-kernel",
		dest="buildIdObjcopyKernel",
		default=None,
		help="objcopy program to use to add build id section in kernel modules")
	parser.add_option("--build-id-section-name",
		dest="buildIdSectionName",
		default=None,
		help="name of build id section to add")
	parser.add_option("--filelist",
		dest="fileListPath",
		default=None,
		help="file where to store list of installed files")
	parser.add_option("--keep-python-files",
		dest="keepPythonFiles",
		action="store_true",
		default=False,
		help="keep python files (*.py, *.pyc, *.pyo)")
	parser.add_option("--mode",
		dest="mode",
		default=MODE_DEFAULT,
		help="generation mode (what to put/filter): %s (default is %s)" % (
				", ".join(MODES), MODE_DEFAULT))

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
	if len(args) > 3:
		parser.error("Too many parameters")
	elif len(args) < 2:
		parser.error("Not enough parameters")
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
