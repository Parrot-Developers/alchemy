#!/usr/bin/env python

import sys, os, logging
import optparse
import subprocess
import stat
import tempfile

import libplf

#===============================================================================
#===============================================================================
class Context(object):
	def __init__(self, options, args):
		self.plfFilePath = args[0]
		self.dryRun = options.dryRun
		self.adbDevice = options.adbDevice

#===============================================================================
#===============================================================================
def execAdb(ctx, args):
	if ctx.adbDevice is None:
		args = ["adb"] + args
	else:
		args = ["adb", "-s", ctx.adbDevice] + args
	logging.debug("Exec: %s", " ".join(args))
	if ctx.dryRun:
		return ""
	process = subprocess.Popen(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
	out = process.communicate()[0].rstrip("\n")
	if out:
		print(out)

#===============================================================================
#===============================================================================
def pushDir(ctx, section):
	print("Dir: %s" % section.path)
	args = ["shell", "mkdir", "-p", section.path]
	execAdb(ctx, args)
	args = ["shell", "chmod", "0%o" % stat.S_IMODE(section.mode), section.path]
	execAdb(ctx, args)
	args = ["shell", "chown", "%d:%d" % (section.gid, section.uid), section.path]
	execAdb(ctx, args)

#===============================================================================
#===============================================================================
def pushLink(ctx, section):
	# Ask plftool to extract the link so we can read its target
	# We need to provide a temp file name that does not exist...
	tmpFilePath = "/tmp/pushplf%d" % os.getpid()
	libplf.plftoolExec(["-j", "U_UNIXFILE:%d" % section.idxSection,
			"-x", tmpFilePath, ctx.plfFilePath])
	linkTarget = os.readlink(tmpFilePath)
	os.unlink(tmpFilePath)

	print("Link: %s -> %s" % (section.path, linkTarget))

	# Android 'ln' does not support '-f' option
	args = ["shell", "rm", "-f", section.path]
	execAdb(ctx, args)
	args = ["shell", "ln", "-s", linkTarget, section.path]
	execAdb(ctx, args)

#===============================================================================
#===============================================================================
def pushFile(ctx, section):
	print("File: %s" % section.path)

	# Ask plftool to extract the file somewhere
	(tmpFileFd, tmpFilePath) = tempfile.mkstemp()
	libplf.plftoolExec(["-j", "U_UNIXFILE:%d" % section.idxSection,
			"-x", tmpFilePath, ctx.plfFilePath])
	os.close(tmpFileFd)

	# push file and update its mode
	args = ["push", tmpFilePath, section.path]
	execAdb(ctx, args)
	args = ["shell", "chmod", "0%o" % stat.S_IMODE(section.mode), section.path]
	execAdb(ctx, args)
	args = ["shell", "chown", "%d:%d" % (section.gid, section.uid), section.path]
	execAdb(ctx, args)

	# Cleanup
	os.unlink(tmpFilePath)

#===============================================================================
#===============================================================================
def main():
	(options, args) = parseArgs()
	setupLog(options)

	ctx = Context(options, args)

	# Load plf
	plf = libplf.PlfFileInfo()
	plf.load(ctx.plfFilePath)

	# Push U_UNIXFILE sections
	for section in plf.sections:
		if section.type != "U_UNIXFILE":
			continue
		if stat.S_ISDIR(section.mode):
			pushDir(ctx, section)
		elif stat.S_ISLNK(section.mode):
			pushLink(ctx, section)
		elif stat.S_ISREG(section.mode):
			pushFile(ctx, section)
		else:
			logging.warning("Invalid section mode: %0o", section.mode)

#===============================================================================
# Setup option parser and parse command line.
#===============================================================================
def parseArgs():
	# Setup parser
	usage = "usage: %prog [options] <plf-file>"
	parser = optparse.OptionParser(usage=usage)

	parser.add_option("-n",
		dest="dryRun",
		action="store_true",
		default=False,
		help="dry run, don't push anything")

	parser.add_option("-s",
		dest="adbDevice",
		default=None,
		help="adb device to use (see -s option of adb)")

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
	if len(args) != 1:
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
