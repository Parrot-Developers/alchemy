#!/usr/bin/env python

import sys, os, logging
import optparse
import tarfile

#===============================================================================
# Determine if a file is an executable.
#===============================================================================
def isExec(filePath):
    result = False
    try:
        fd = open(filePath, "rb")
        header = str(fd.read(4))
        if header.find("ELF") >= 0:
            result = True
        fd.close()
    except IOError as ex:
        logging.error("Failed to open file: %s ([err=%d] %s)",
            filePath, ex.errno, ex.strerror)
    return result

#===============================================================================
#===============================================================================
def getFileList(stagingDir):
    usrSrcValaDir = os.path.join(stagingDir, "usr", "src", "vala")
    result = []
    for (dirPath, dirNames, fileNames) in os.walk(stagingDir):
        for fileName in fileNames:
            filePath = os.path.join(dirPath, fileName)
            if os.path.islink(filePath):
                targetPath = os.path.realpath(filePath)
                if targetPath in result:
                    result.append(filePath)
                elif targetPath.startswith(stagingDir) and isExec(targetPath):
                    result.append(filePath)
                    result.append(targetPath)
            elif filePath not in result:
                if isExec(filePath) or filePath.startswith(usrSrcValaDir):
                    result.append(filePath)
    return result

#===============================================================================
#===============================================================================
def createTarFile(outTarFile, fileList, stagingDir, symbolsRoot):
    # Create tar file
    try:
        tarfd = tarfile.open(outTarFile, "w")
    except tarfile.TarError as ex:
        logging.error("Failed to create file: %s ([err=%d] %s)",
            outTarFile, ex.errno, ex.strerror)
        sys.exit(1)

    symbolsRoot = symbolsRoot.strip("/")
    for filePath in fileList:
        fileRelPath = os.path.relpath(filePath, stagingDir)
        fileName = os.path.join("symbols", symbolsRoot, fileRelPath)
        logging.info("Adding %s", fileRelPath)
        tarfd.add(name=filePath, arcname=fileName)

    tarfd.close()

#===============================================================================
# Main function.
#===============================================================================
def main():
    (options, args) = parseArgs()
    setupLog(options)

    stagingDir = args[0]
    outTarFile = args[1]

    fileList = getFileList(stagingDir)
    createTarFile(outTarFile, fileList, stagingDir, options.symbolsRoot)

#===============================================================================
# Setup option parser and parse command line.
#===============================================================================
def parseArgs():
    # Setup parser
    usage = "usage: %prog [options] <staging-dir> <out-tar-file>"
    parser = optparse.OptionParser(usage=usage)

    # Main options
    parser.add_option("--symbols-root",
        dest="symbolsRoot",
        default="",
        help="Extra root directory name to add in tar file")

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
