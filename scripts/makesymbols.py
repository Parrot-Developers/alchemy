#!/usr/bin/env python3

import sys, os, logging
import argparse
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
def createTarFile(outTarFile, fileList, stagingDir):
    # Create tar file
    try:
        tarfd = tarfile.open(outTarFile, "w")
    except tarfile.TarError as ex:
        logging.error("Failed to create file: %s (%s)", outTarFile, str(ex))
        sys.exit(1)

    for filePath in fileList:
        fileRelPath = os.path.relpath(filePath, stagingDir)
        fileName = os.path.join("symbols", fileRelPath)
        logging.info("Adding %s", fileRelPath)
        tarfd.add(name=filePath, arcname=fileName)

    tarfd.close()

#===============================================================================
# Main function.
#===============================================================================
def main():
    options = parseArgs()
    setupLog(options)

    fileList = getFileList(options.stagingDir)
    createTarFile(options.outTarFile, fileList, options.stagingDir)

#===============================================================================
# Setup option parser and parse command line.
#===============================================================================
def parseArgs():
    # Setup parser
    parser = argparse.ArgumentParser()

    # Positional arguments
    parser.add_argument("stagingDir", help="Staging directory")
    parser.add_argument("outTarFile", help="OUtput tar file")

    # Other options
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

    # Parse arguments
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
