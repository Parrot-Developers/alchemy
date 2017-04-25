#!/usr/bin/env python3
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
import stat
import subprocess
import argparse
import re
import fnmatch

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
    MODE_FIRWMARE: EXCLUDE_FILTERS_ALWAYS + [".a", ".la", ".o", ".lo", ".prl"],
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
    process = subprocess.Popen(cmd, stdout=subprocess.PIPE, shell=True)
    return process.communicate()[0].rstrip("\n").split("\n")

#===============================================================================
# Determine if a file is an executable.
#===============================================================================
def isExec(filePath):
    try:
        with open(filePath, "rb") as fd:
            hdr = fd.read(4)
            if hdr == b"\x7fELF" or hdr[:2] == b"MZ":
                return True
    except IOError as ex:
        logging.error("Failed to open file: %s ([err=%d] %s)",
            filePath, ex.errno, ex.strerror)
    return False

#===============================================================================
# Determine if a file can be stripped.
# Required under android because soslim crashes when trying to strip
# static executables compiled with eglibc.
#===============================================================================
def canStrip(filePath):
    result = False
    try:
        # get error output from nm command to check for 'no symbols'
        process = subprocess.Popen("nm %s" % filePath,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
        res = process.communicate()[1].decode("UTF-8").rstrip("\n").split("\n")
        result = (len(res) == 0 or res[0].find("no symbols") < 0)
    except IOError:
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
            path = os.path.normpath(os.path.join(os.path.dirname(path), resolved))
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
# Get the commands to be executed for the copy.
#===============================================================================
def getCopyCmds(dstFileName, srcFileName, options, doStrip=False):
    cmds = []
    if not doStrip:
        # Simple copy
        cmds.append("cp -af \"%s\" \"%s\"" % (srcFileName, dstFileName))
    else:
        if doStrip:
            if srcFileName.endswith(".ko") and options.stripKernel is not None:
                cmds.append("%s -o \"%s\" \"%s\"" % \
                    (options.stripKernel, dstFileName, srcFileName))
            else:
                cmds.append("%s -o \"%s\" \"%s\"" % \
                    (options.strip, dstFileName, srcFileName))
        # Restore mode and timestamp
        mode = stat.S_IMODE(os.stat(srcFileName).st_mode)
        cmds.append("chmod 0%o \"%s\"" % (mode, dstFileName))
        cmds.append("touch -r \"%s\" \"%s\"" % (srcFileName, dstFileName))
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
    if options.fileListFile is None:
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
    if options.strip is not None \
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
    if not doAction:
        return
    if os.path.islink(srcFileName):
        logging.info("Link : %s", relPath)
    else:
        logging.info("File : %s", relPath)

    # make sure destination directory exists
    dstDirName = os.path.split(dstFileName)[0]
    if not os.path.lexists(dstDirName):
        os.makedirs(dstDirName, 0o755)

    # do the copy by wanted method (always process links directly)
    if options.makefile is not None and not os.path.islink(srcFileName):
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
                    os.makedirs(dstDirName, 0o755)

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
                doCopy(dstFileName, srcFileName, options, forceCopy=forceCopy)

#===============================================================================
# Process linux basic skel.
#===============================================================================
def processLinuxBasicSkel(options):
    for entry in LINUX_BASIC_SKEL:
        if entry[1] is None:
            dstDirName = getRealPath(options.finalDir, entry[0])
            if not os.path.lexists(dstDirName):
                logging.info("Directory : %s", entry[0])
                os.makedirs(dstDirName, 0o755)
        else:
            dstLnkName = getRealPath(options.finalDir, entry[0])
            logging.info("Link : %s", entry[0])
            os.system("ln -sf \"%s\" \"%s\"" % (entry[1], dstLnkName))

#===============================================================================
# Main function.
#===============================================================================
def main():
    options = parseArgs()
    setupLog(options)

    # get parameters
    options.stagingDir = os.path.realpath(options.stagingDir)
    options.finalDir = os.path.realpath(options.finalDir)
    logging.info("staging-dir : %s", options.stagingDir)
    logging.info("final-dir : %s", options.finalDir)

    # do we need to output a makefile ?
    makefilePath = options.makefile
    if options.makefile is not None:
        logging.info("makefile : %s", makefilePath)
        try:
            options.makefile = Makefile(open(makefilePath, "w"))
        except IOError as ex:
            logging.error("Failed to create file: %s [err=%d %s]",
                    makefilePath, ex.errno, ex.strerror)

    # update filter
    if options.mode != MODE_FULL and not options.keepPythonFiles:
        EXCLUDE_FILTERS[options.mode].extend(EXCLUDE_FILTERS_PYTHON)

    # filelist file
    options.fileListFile = None
    options.fileListDirs = []
    if options.fileListPath is not None:
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

    if options.makefile is not None:
        options.makefile.write(options)
        options.makefile.fout.close()

#===============================================================================
# Setup option parser and parse command line.
#===============================================================================
def parseArgs():
    parser = argparse.ArgumentParser()
    parser.add_argument("stagingDir",
            help="Staging directory.")
    parser.add_argument("finalDir",
            help="Final directory.")
    parser.add_argument("makefile",
            nargs="?",
            help="Output makefile.")
    parser.add_argument("--strip",
        dest="strip",
        default=None,
        metavar="STRIP",
        help="strip program to use to remove symbols")
    parser.add_argument("--strip-kernel",
        dest="stripKernel",
        default=None,
        metavar="STRIP",
        help="strip program to use to remove symbols from kernel modules")
    parser.add_argument("--skel",
        dest="skelDirs",
        default=[],
        action="append",
        metavar="DIR",
        help="path to skeleton tree to merge in final tree")
    parser.add_argument("--linux-basic-skel",
        dest="linuxBasicSkel",
        action="store_true",
        default=False,
        help="Create a basic linux skel (proc, dev, tmp...)")
    parser.add_argument("--strip-filter",
        dest="stripFilters",
        default=[],
        action="append",
        metavar="FILTER",
        help="Filter of file names that will no be stripped (ex: ld-*.so)")
    parser.add_argument("--remove-wgo",
        dest="removeWGO",
        action="store_true",
        default=False,
        help="Remove write access for group and other on all copied files")
    parser.add_argument("--filelist",
        dest="fileListPath",
        default=None,
        metavar="FILE",
        help="file where to store list of installed files")
    parser.add_argument("--keep-python-files",
        dest="keepPythonFiles",
        action="store_true",
        default=False,
        help="keep python files (*.py, *.pyc, *.pyo)")
    parser.add_argument("--mode",
        dest="mode",
        default=MODE_DEFAULT,
        choices=MODES,
        help="generation mode (what to put/filter) (default is %s)" % MODE_DEFAULT)

    parser.add_argument("-q",
        dest="quiet",
        action="store_true",
        default=False,
        help="be quiet")
    parser.add_argument("-v",
        dest="verbose",
        action="count",
        default=0,
        help="verbose output (more verbose if specified twice)")

    return parser.parse_args()

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
    if options.quiet:
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
