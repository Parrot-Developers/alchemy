#!/usr/bin/env python

import sys, os, logging
import optparse
import shutil
import fnmatch
import xml.parsers

from cStringIO import StringIO

import moduledb

#===============================================================================
#===============================================================================
class Context(object):
	def __init__(self, args):
		self.dumpXmlPath = os.path.abspath(args[0])
		self.hostBuildDir = os.path.abspath(args[1])
		self.hostStagingDir = os.path.abspath(args[2])
		self.buildDir = os.path.abspath(args[3])
		self.stagingDir = os.path.abspath(args[4])
		self.outDir = os.path.abspath(args[5])
		self.atom = StringIO()
		self.setup = StringIO()
		self.sdkDirs = []
		self.moduledb = None
		self.headerLibs = []

#===============================================================================
# Similar to shutil.copytree but does not fail if destination exists
# Also, the ignore argument is removed
#===============================================================================
def copyTree(src, dst, symlinks=False, exclude=None):
	names = os.listdir(src)
	if not os.path.exists(dst):
		os.makedirs(dst, mode=0755)
	errors = []
	for name in names:
		srcname = os.path.join(src, name)
		dstname = os.path.join(dst, name)
		try:
			if symlinks and os.path.islink(srcname):
				if not os.path.lexists(dstname):
					linkto = os.readlink(srcname)
					logging.debug("Link: '%s' -> '%s'", srcname, dstname)
					os.symlink(linkto, dstname)
			elif os.path.isdir(srcname):
				copyTree(srcname, dstname, symlinks, exclude)
			else:
				# Will raise a SpecialFileError for unsupported file types
				if exclude and any([fnmatch.fnmatch(os.path.basename(srcname), ext) for ext in exclude]):
					# Ignore this file
					pass
				elif not os.path.lexists(dstname):
					logging.debug("Copy: '%s' -> '%s'", srcname, dstname)
					shutil.copy2(srcname, dstname)
		# catch the Error from the recursive copyTree so that we can
		# continue with other files
		except shutil.Error, err:
			errors.extend(err.args[0])
		except EnvironmentError, why:
			errors.append((srcname, dstname, str(why)))
	try:
		shutil.copystat(src, dst)
	except OSError, why:
		if shutil.WindowsError is not None and isinstance(why, shutil.WindowsError):
			# Copying file access times may fail on Windows
			pass
		else:
			errors.append((src, dst, str(why)))
	if errors:
		raise shutil.Error, errors

#===============================================================================
#===============================================================================
def copyHostStaging(srcDir, dstDir):
	logging.debug("Copy host staging: '%s' -> '%s'", srcDir, dstDir)
	exclude = ["*.la"]
	copyTree(srcDir, dstDir, symlinks=True, exclude=exclude)

#===============================================================================
#===============================================================================
def copyStaging(srcDir, dstDir):
	logging.debug("Copy staging: '%s' -> '%s'", srcDir, dstDir)
	dirs_to_keep = ["lib" ,
		os.path.join("etc", "alternatives"),
		os.path.join("usr", "lib"),
		os.path.join("usr", "include"),
		os.path.join("usr", "share", "vala"),
		os.path.join("usr", "src", "linux-sdk"),
		os.path.join("usr", "local", "cuda-6.5"),
		os.path.join("usr", "local", "cuda-7.0"),
		"host",
		"android",
		"toolchain",
	]
	exclude = ["*.la"]
	for dirName in dirs_to_keep:
		if os.path.exists(os.path.join(srcDir, dirName)):
			srcDirPath=os.path.normpath(os.path.join(srcDir, dirName))
			dstDirPath=os.path.normpath(os.path.join(dstDir, dirName))
			copyTree(srcDirPath, dstDirPath, symlinks=True, exclude=exclude)

#===============================================================================
#===============================================================================
def copySdk(srcDir, dstDir):
	logging.debug("Copy sdk: '%s' -> '%s'", srcDir, dstDir)
	copyStaging(srcDir, dstDir)

#===============================================================================
#===============================================================================
def copyHeaders(srcDir, dstDir):
	logging.debug("Copy headers: '%s' -> '%s'", srcDir, dstDir)
	extensions = ["*.h", "*.hpp", "*.hh", "*.hxx", "*.doxygen", "*.inl"]
	copyElements(srcDir, dstDir, extensions)

#===============================================================================
#===============================================================================
def copyLibs(srcDir, dstDir):
	logging.debug("Copy libs: '%s' -> '%s'", srcDir, dstDir)
	extensions = ["*.a"]
	# Limit the copy to the base of the module
	copyElements(srcDir, dstDir, extensions, depth=1)

#===============================================================================
# Copy elements based on their extensions and limiting to a max depth if any
# If no extension is provided, any element will be took into account
#===============================================================================
def copyElement(srcPath, dstPath, keepLinks=False):
	if not os.path.exists(os.path.dirname(dstPath)):
		os.makedirs(os.path.dirname(dstPath), mode=0755)

	# Set the function to use for copy
	if os.path.isdir(srcPath):
		copy_func = { "function":copyTree, "description":"Copy"}
	else:
		copy_func = { "function":shutil.copy2, "description":"Copy"}

	if os.path.islink(srcPath):
		# We voluntarily make no normalization of path
		# as the final environment may be peculiar
		srcPath = os.readlink(srcPath)
		# If asked to keep links instead of hard copy,
		# change the function to use
		if keepLinks:
			copy_func = { "function":os.symlink, "description":"Link"}
	# Do the copy/symlink
	if not os.path.lexists(dstPath):
		logging.debug("%s: '%s' -> '%s'", copy_func["description"], srcPath, dstPath)
		copy_func["function"](srcPath, dstPath)

#===============================================================================
#===============================================================================
def copyElements(srcDir, dstDir, extensions=["*"], depth=0,
		keepLinks=False, keepInclude=False, scanDirs=False):
	if not os.path.exists(srcDir):
		logging.warning("Missing directory: '%s'", srcDir)

	# Manage depth only if provided or different than 0
	if depth is None or depth == 0:
		current_depth = None
	else:
		# Save the current level
		current_depth = os.path.normpath(srcDir).count(os.sep)

	# When executed with LANG=C (via alchemy) os.walk crashes when a path
	# with accents is found. We force utf8 encoding to solve the issue.
	srcDir = srcDir.encode("utf-8")
	dstDir = dstDir.encode("utf-8")
	for (dirPath, dirNames, fileNames) in os.walk(srcDir):
		# Aren't we deep enough to parse the content of the files
		if current_depth:
			# We use continue instead of break,
			# In order not to skip potentials remaining directories
			if os.path.normpath(dirPath).count(os.sep) > (current_depth + depth):
				continue

		for fileName in fileNames:
			# Get normalized path for src and dst
			srcFilePath = os.path.normpath(os.path.join(dirPath, fileName))
			relPath = os.path.relpath(srcFilePath, srcDir)
			dstFilePath = os.path.normpath(os.path.join(dstDir, relPath))
			if any([fnmatch.fnmatch(os.path.basename(srcFilePath), ext) for ext in extensions]):
				copyElement(srcFilePath, dstFilePath, keepLinks=keepLinks)

#===============================================================================
# Remove symlinks whose target does not exists or is an absolute path.
#===============================================================================
def checkSymlinks(srcDir):
	logging.info("Checking symlinks")
	for (dirPath, dirNames, fileNames) in os.walk(srcDir):
		for fileName in fileNames:
			srcFilePath = os.path.join(dirPath, fileName)
			if not os.path.islink(srcFilePath):
				continue
			if not os.path.exists(srcFilePath):
				logging.info("Removing dangling symlink: '%s'", srcFilePath)
				os.unlink(srcFilePath)
			elif os.path.isabs(os.readlink(srcFilePath)):
				logging.info("Removing absolute symlink: '%s'", srcFilePath)
				os.unlink(srcFilePath)

#===============================================================================
#===============================================================================
def processModule(ctx, module, headersOnly=False):
	# Skip module not built
	if not module.build and not headersOnly:
		return
	logging.info("Processing module %s", module.name)

	# Remember modules not built but whose headers are required
	if not headersOnly and "DEPENDS_HEADERS" in module.fields:
		libs = module.fields["DEPENDS_HEADERS"].split()
		for lib in libs:
			if lib not in ctx.headerLibs \
					and lib in ctx.moduledb \
					and not ctx.moduledb[lib].build:
				ctx.headerLibs.append(lib)

	# Start a new module
	ctx.atom.write("include $(CLEAR_VARS)\n")
	modulePath = module.fields["PATH"]
	moduleClass = module.fields["MODULE_CLASS"]

	# Write verbatim some fields (and escape quotes)
	fields = ["DESCRIPTION", "CATEGORY_PATH",
			"REVISION", "REVISION_DESCRIBE",
			"FORCE_WHOLE_STATIC_LIBRARY",
			"EXPORT_CFLAGS", "EXPORT_CXXFLAGS"]
	for field in fields:
		if field in module.fields and module.fields[field] :
			ctx.atom.write("LOCAL_%s := %s\n" % (field, module.fields[field]))

	if module.name.startswith("host."):
		ctx.atom.write("LOCAL_HOST_MODULE := %s\n" % module.name[5:])
	else:
		ctx.atom.write("LOCAL_MODULE := %s\n" % module.name)

	# Libraries
	# If a module contains prelinked '.a' mentionned in its EXPORT_LDLIBS, copy
	# them and uptade the variable
	if not headersOnly and "EXPORT_LDLIBS" in module.fields:
		libs = module.fields["EXPORT_LDLIBS"].split()
		newLibs = []
		for lib in libs:
			if lib.startswith("-L" + modulePath):
				libDir = lib[2:]
				# TODO: simplify destination by remove extra 'lib' and 'module name'
				relPath = os.path.relpath(libDir, modulePath)
				if relPath != ".":
					dstDir = os.path.join("usr", "lib", module.name, relPath)
				else:
					dstDir = os.path.join("usr", "lib", module.name)
				# Copy libs and add new directory only if files have actually
				# been copied (ie directory was created)
				copyLibs(libDir, os.path.join(ctx.outDir, dstDir))
				if os.path.exists(os.path.normpath(os.path.join(ctx.outDir, dstDir))):
					newLibs.append("-L$(LOCAL_PATH)/" + dstDir)
			elif lib.startswith(ctx.stagingDir):
				# Some module directly reference a path in staging, simply update
				# path, normally the file is already copied
				relPath = os.path.relpath(lib, ctx.stagingDir)
				newLibs.append("$(LOCAL_PATH)/" + relPath)
			else:
				newLibs.append(lib)
		# Write libs in a readable way
		ctx.atom.write("LOCAL_EXPORT_LDLIBS :=")
		for lib in newLibs:
			ctx.atom.write(" \\\n\t%s" % lib)
		ctx.atom.write("\n")

	# Include directories
	if "EXPORT_C_INCLUDES" in module.fields:
		includeDirs = module.fields["EXPORT_C_INCLUDES"].split()
		# First, convert path
		newIncludeDirs = []
		for includeDir in includeDirs:
			if includeDir.startswith(modulePath):
				# TODO: simplify destination by remove extra 'include' and 'module name'
				relPath = os.path.relpath(includeDir, modulePath)
				if relPath != ".":
					dstDir = os.path.join("usr", "include", module.name,
							relPath.replace("..", "dotdot"))
				else:
					dstDir = os.path.join("usr", "include", module.name)
				# Copy headers and add new directory only if files have actually
				# been copied (ie directory was created)
				copyHeaders(includeDir, os.path.join(ctx.outDir, dstDir))
				if os.path.exists(os.path.normpath(os.path.join(ctx.outDir, dstDir))):
					newIncludeDirs.append("$(LOCAL_PATH)/" + dstDir)
			elif includeDir.startswith(os.path.join(ctx.buildDir, module.name)):
				# TODO: simplify destination by remove extra 'include' and 'module name'
				relPath = os.path.relpath(includeDir, os.path.join(ctx.buildDir, module.name))
				if relPath != ".":
					dstDir = os.path.join("usr", "include", module.name,
							relPath.replace("..", "dotdot"))
				else:
					dstDir = os.path.join("usr", "include", module.name)
				# Copy headers and add new directory only if files have actually
				# been copied (ie directory was created)
				copyHeaders(includeDir, os.path.join(ctx.outDir, dstDir))
				if os.path.exists(os.path.normpath(os.path.join(ctx.outDir, dstDir))):
					newIncludeDirs.append("$(LOCAL_PATH)/" + dstDir)
			elif includeDir.startswith(ctx.stagingDir + "/"):
				relPath = os.path.relpath(includeDir, ctx.stagingDir)
				# Only add existing directory that is not in a standard place
				if relPath != "usr/include" and os.path.exists(includeDir):
					newIncludeDirs.append("$(LOCAL_PATH)/" + relPath)
			elif includeDir.startswith(ctx.hostStagingDir + "/"):
				relPath = os.path.relpath(includeDir, ctx.hostStagingDir)
				# Only add existing directory that is not in a standard place
				if relPath != "usr/include" and os.path.exists(includeDir):
					newIncludeDirs.append("$(LOCAL_PATH)/host/" + relPath)
			elif includeDir.startswith("/opt/"):
				# Assume it is a required host package installed externally
				newIncludeDirs.append(includeDir)
			else:
				logging.warning("Ignoring include dir: '%s'", includeDir)
		# Write path in a readable way
		ctx.atom.write("LOCAL_EXPORT_C_INCLUDES :=")
		for includeDir in newIncludeDirs:
			ctx.atom.write(" \\\n\t%s" % includeDir)
		ctx.atom.write("\n")

	# Config file
	# Note: for sdk modules, LOCAL_CONFIG_FILES will simply indicate that a
	# config file is present, reconfiguration will not be possible.
	if "CONFIG_FILES" in module.fields:
		configFileName = "%s.config" % module.name
		srcFilePath = os.path.join(ctx.buildDir, module.name, configFileName)
		dstDirPath = os.path.join(ctx.outDir, "config")
		if os.path.exists(srcFilePath):
			if not os.path.exists(dstDirPath):
				os.makedirs(dstDirPath, mode=0755)
			shutil.copy2(srcFilePath, os.path.join(dstDirPath, configFileName))
			ctx.atom.write("LOCAL_CONFIG_FILES := 1\n")
			ctx.atom.write("sdk.%s.config := $(LOCAL_PATH)/config/%s\n" % (
					module.name, configFileName))
			ctx.atom.write("$(call load-config)\n")

	# Set LOCAL_LIBRARIES with the content of 'depends'
	if not headersOnly and "depends" in module.fields:
		ctx.atom.write("LOCAL_LIBRARIES := %s\n" % module.fields["depends"])

	# Register shared/static libraries as normal so we can manage dependencies
	# Other are simply put as prebuilt
	ctx.atom.write("LOCAL_SDK := $(LOCAL_PATH)\n")
	if moduleClass in ["SHARED_LIBRARY", "STATIC_LIBRARY", "LIBRARY"]:
		ctx.atom.write("LOCAL_DESTDIR := %s\n" % module.fields["DESTDIR"])
		ctx.atom.write("LOCAL_MODULE_FILENAME := %s\n" % module.fields["MODULE_FILENAME"])
		ctx.atom.write("include $(BUILD_%s)\n" % moduleClass)
	else:
		ctx.atom.write("include $(BUILD_PREBUILT)\n")

	# End of module
	ctx.atom.write("\n")

#===============================================================================
#===============================================================================
def checkTargetVar(ctx, name):
	val = ctx.moduledb.targetVars.get(name, "")
	if val:
		ctx.atom.write("ifneq (\"$(TARGET_%s)\",\"%s\")\n" % (name, val))
		ctx.atom.write("  $(error This sdk is for TARGET_%s=%s)\n" % (name, val))
		ctx.atom.write("endif\n\n")

#===============================================================================
#===============================================================================
def writeTargetSetupVars(ctx, name):
	val = ctx.moduledb.targetSetupVars.get(name, "")
	if val:
		# Replace directory path referencing previous sdk or staging directory
		for dirPath in ctx.sdkDirs:
			val = val.replace(dirPath, "$(LOCAL_PATH)")
		val = val.replace(ctx.stagingDir, "$(LOCAL_PATH)")
		ctx.setup.write("TARGET_%s :=" % name)
		for field in val.split():
			if field.startswith("-"):
				ctx.setup.write(" \\\n\t%s" % field)
			else:
				ctx.setup.write(" %s" % field)
		ctx.setup.write("\n\n")

#===============================================================================
# Main function.
#===============================================================================
def main():
	(options, args) = parseArgs()
	setupLog(options)

	# Extract arguments
	ctx = Context(args)

	# Load modules from xml
	logging.info("Loading xml '%s'", ctx.dumpXmlPath)
	try:
		ctx.moduledb = moduledb.loadXml(ctx.dumpXmlPath)
	except xml.parsers.expat.ExpatError as ex:
		sys.stderr.write("Error while loading '%s':\n" % ctx.dumpXmlPath)
		sys.stderr.write("  %s\n" % ex)
		sys.exit(1)

	# List of previous sdk to merge with the new one
	ctx.sdkDirs = ctx.moduledb.targetVars.get("SDK_DIRS", "").split()

	# Setup output directory
	logging.info("Initializing output directory '%s'", ctx.outDir)
	if os.path.exists(ctx.outDir):
		shutil.rmtree(ctx.outDir)
	os.makedirs(ctx.outDir, mode=0755)

	# Copy content of host staging directory
	if os.path.exists(ctx.hostStagingDir):
		logging.info("Copying host staging directory")
		copyHostStaging(ctx.hostStagingDir, os.path.join(ctx.outDir, "host"))

	# Copy content of staging directory
	logging.info("Copying staging directory")
	copyStaging(ctx.stagingDir, ctx.outDir)

	# Copy content of previous sdk
	for srcDir in ctx.sdkDirs:
		copySdk(srcDir, ctx.outDir)

	# Add some TARGET_XXX variables checks to make sure that the sdk is used
	# in the correct environment
	target_elements = [
		 "OS", "OS_FLAVOUR",
		"ARCH", "CPU", "CROSS",
		"LIBC", "DEFAULT_ARM_MODE" ]
	for element_to_check in target_elements:
		checkTargetVar(ctx, element_to_check)

	# Save initial TARGET_SETUP_XXX variables as TARGET_XXX
	for var in ctx.moduledb.targetSetupVars.keys():
		writeTargetSetupVars(ctx, var)

	# Process modules
	for module in ctx.moduledb:
		processModule(ctx, module)

	# Process modules not built but whose headers are required
	for lib in ctx.headerLibs:
		processModule(ctx, ctx.moduledb[lib], headersOnly=True)

	# Check  symlinks
	checkSymlinks(ctx.outDir)

	# Process custom macros
	for macro in ctx.moduledb.customMacros.values():
		ctx.atom.write("define %s\n" % macro.name)
		ctx.atom.write(macro.value)
		ctx.atom.write("\nendef\n")
		ctx.atom.write("$(call local-register-custom-macro,%s)\n" % macro.name)

	# Write the atom.mk
	with open(os.path.join(ctx.outDir, "atom.mk"), "w") as atomFile:
		atomFile.write("# GENERATED FILE, DO NOT EDIT\n\n")
		atomFile.write("LOCAL_PATH := $(call my-dir)\n\n")
		atomFile.write(ctx.atom.getvalue())

	# Write the setup.mk
	with open(os.path.join(ctx.outDir, "setup.mk"), "w") as setupFile:
		setupFile.write("# GENERATED FILE, DO NOT EDIT\n\n")
		setupFile.write("LOCAL_PATH := $(call my-dir)\n\n")
		setupFile.write(ctx.setup.getvalue())
		setupFile.write("\n")

#===============================================================================
# Setup option parser and parse command line.
#===============================================================================
def parseArgs():
	# Setup parser
	usage = "usage: %prog [options] <dump-xml> <host-build-dir>" \
			" <host-staging-dir> <build-dir> <staging-dir> <out-dir>"
	parser = optparse.OptionParser(usage=usage)

	# Main options

	# Other options
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
	if len(args) != 6:
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

	# Setup log level
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
