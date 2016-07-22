#!/usr/bin/env python3

import sys, os, logging
import argparse

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
    try:
        with open(filePath, "rb") as fd:
            if fd.read(4) == b"\x7fELF":
                return True
    except IOError as ex:
        logging.error("Failed to open file: %s ([err=%d] %s)",
            filePath, ex.errno, ex.strerror)
    return False

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
    options = parseArgs()
    setupLog(options)

    ctx = Context()

    # Process all ELF files in given root directory
    for (dirPath, dirNames, fileNames) in os.walk(options.rootDir):
        for excludeDir in ["proc", "sys", "dev"]:
            if excludeDir in dirNames:
                dirNames.remove(excludeDir)
        for fileName in fileNames:
            filePath = os.path.join(dirPath, fileName)
            if os.path.islink(filePath) or not isElf(filePath):
                continue
            processFile(ctx, filePath)

    # Determine missing libraries
    for (dirPath, dirNames, fileNames) in os.walk(options.rootDir):
        for fileName in fileNames:
            if fileName in ctx.libraries:
                ctx.libraries[fileName] = True

    # Print result
    for library in ctx.libraries:
        if not ctx.libraries[library]:
            # Only display the first binary that needs the library
            neededBy = None
            for binary in ctx.binaries:
                if library in ctx.binaries[binary]:
                    neededBy = binary
                    break
            logging.warning("Missing library: '%s' needed by %s", library, neededBy)

#===============================================================================
# Setup option parser and parse command line.
#===============================================================================
def parseArgs():
    parser = argparse.ArgumentParser()

    parser.add_argument("rootDir",
            nargs="?",
            default=os.getcwd(),
            help="Root directoty to check")

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

    # Setup log level
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
