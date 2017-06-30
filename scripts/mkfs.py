#!/usr/bin/env python3

import sys, os, logging
import argparse
import re
import stat
import mktar, mkextfs, mkcpio, mkubi

# List of supported file systems
FS_LIST = [
    "tar", "cpio", "ext2", "ext3", "ext4", "ubi"
]

_DEFAULT_IMAGE_SIZE = "256M"

#===============================================================================
#===============================================================================
class MyStat(object):
    def __init__(self, st=None):
        self.st_mode = st.st_mode if st else 0
        self.st_ino = st.st_ino if st else 0
        self.st_dev = st.st_dev if st else 0
        self.st_nlink = st.st_nlink if st else 0
        self.st_uid = st.st_uid if st else 0
        self.st_gid = st.st_gid if st else 0
        self.st_size = st.st_size if st else 0
        self.st_atime = st.st_atime if st else 0
        self.st_mtime = st.st_mtime if st else 0
        self.st_ctime = st.st_ctime if st else 0

#===============================================================================
#===============================================================================
class FsEntry(object):
    def __init__(self, filePath, dataSize, st):
        self.filePath = filePath
        self.fileName = os.path.basename(filePath) if filePath else None
        self.dataSize = dataSize
        self.st = st
        self.children = {}

    def getData(self):
        if stat.S_IFMT(self.st.st_mode) == stat.S_IFLNK:
            return os.readlink(self.filePath).encode("UTF-8")
        elif stat.S_IFMT(self.st.st_mode) == stat.S_IFREG:
            try:
                fin = open(self.filePath, "rb")
                return fin.read()
            except IOError as ex:
                logging.error("Failed to open file: %s [err=%d %s]",
                        self.filePath, ex.errno, ex.strerror)
                return ""
            finally:
                fin.close()

#===============================================================================
#===============================================================================
class FsImage(object):
    def __init__(self, filePath, size, fout):
        self.filePath = filePath
        self.fout = fout
        self.size = size

#===============================================================================
#===============================================================================
def addFsEntry(root, entry):
    logging.debug("Adding entry '%s'", entry.filePath)
    parent = root
    components = entry.filePath.split(os.path.sep)
    for component in components[:-1]:
        if component not in parent.children:
            logging.warning("Missing parent for '%s' in '%s'",
                    component, entry.filePath)
            return
        parent = parent.children[component]
    if entry.fileName in parent.children:
        logging.warning("Entry already present : '%s'", entry.filePath)
        return
    parent.children[entry.fileName] = entry

#===============================================================================
#===============================================================================
def addFsEntries(root, filters):
    # Read file names on stdin
    reLine = re.compile("([^;]*)(;mode=([0-7]*);uid=([0-9]*);gid=([0-9]*))?")
    for line in sys.stdin:
        buf = line.rstrip("\n")
        match = reLine.match(buf)
        filePath = match.group(1)

        if filePath in filters:
            logging.info("Skipping entry: %s", filePath)
            continue

        # Get file info
        st = MyStat(os.lstat(filePath))
        if match.lastindex >= 2:
            st.st_mode = int(match.group(3), 8)
            st.st_uid = int(match.group(4))
            st.st_gid = int(match.group(5))

        if stat.S_IFMT(st.st_mode) == stat.S_IFREG:
            # Regular file
            entry = FsEntry(filePath, st.st_size, st)
        elif stat.S_IFMT(st.st_mode) == stat.S_IFDIR:
            # Directory, no data
            entry = FsEntry(filePath, 0, st)
        elif stat.S_IFMT(st.st_mode) == stat.S_IFLNK:
            # Symbolic link, data is link target
            linkTarget = os.readlink(filePath)
            entry = FsEntry(filePath, len(linkTarget.encode("UTF-8")), st)
        else:
            # Ignore other entries
            continue

        # Add entry in tree
        addFsEntry(root, entry)

#===============================================================================
#===============================================================================
def addDevNodes(root, devNodes):
    # Device nodes
    for devNode in devNodes:
        fields = devNode.split(":")
        filePath = fields[0]
        st = MyStat()
        st.st_mode = int(fields[1], 8)
        st.st_uid = int(fields[2], 10)
        st.st_gid = int(fields[3], 10)
        devtype = fields[4]
        major = int(fields[5], 10)
        minor = int(fields[6], 10)
        st.st_dev = os.makedev(major, minor)
        if devtype == "b":
            st.st_mode |= stat.S_IFBLK
        elif devtype == "c":
            st.st_mode |= stat.S_IFCHR
        else:
            logging.warning("Invalid device type '%s'", devtype)
            continue
        # No data, only header
        entry = FsEntry(filePath, 0, st)
        addFsEntry(root, entry)

#===============================================================================
# Main function.
#===============================================================================
def main():
    options = parseArgs()
    setupLog(options)

    # Determine image size
    if options.imageSize.endswith("K"):
        imageSize = int(options.imageSize[:-1]) * 1024
    elif options.imageSize.endswith("M"):
        imageSize = int(options.imageSize[:-1]) * 1024 * 1024
    elif options.imageSize.endswith("G"):
        imageSize = int(options.imageSize[:-1]) * 1024 * 1024 * 1024
    else:
        imageSize = int(options.imageSize)

    # Open output image file (for reading and writing to be mapped)
    if options.fstype != "ubi":
        try:
            fout = open(options.imageFile, "w+b")
        except IOError as ex:
            logging.error("Failed to create file: %s [err=%d %s]",
                    options.imageFile, ex.errno, ex.strerror)
            sys.exit(1)
    else:
        fout = None

    image = FsImage(options.imageFile, imageSize, fout)

    # Construct image from root
    root = FsEntry(None, 0, None)
    addFsEntries(root, options.filters)
    addDevNodes(root, options.devNodes)

    # Generate the ouput file
    try:
        if options.fstype == "tar":
            mktar.genImage(image, root)
        elif options.fstype == "cpio":
            mkcpio.genImage(image, root)
        elif options.fstype == "ext2":
            mkextfs.genImage(image, root, 2)
        elif options.fstype == "ext3":
            mkextfs.genImage(image, root, 3)
        elif options.fstype == "ext4":
            mkextfs.genImage(image, root, 4)
        elif options.fstype == "ubi":
            mkubi.genImage(image, root, options)
    except Exception as ex:
        logging.error(str(ex))
        sys.exit(1)

#===============================================================================
# Setup option parser and parse command line.
#===============================================================================
def parseArgs():
    parser = argparse.ArgumentParser()

    parser.add_argument("imageFile", help="image file path")

    parser.add_argument("--fstype",
        dest="fstype",
        default=None,
        required=True,
        choices=FS_LIST,
        help="file system type")

    parser.add_argument("--size",
        dest="imageSize",
        default=_DEFAULT_IMAGE_SIZE,
        metavar="SIZE",
        help="file system image size (in bytes, suffixes K,M,G allowed)")

    parser.add_argument("--devnode",
        dest="devNodes",
        action="append",
        default=[],
        metavar="NODE",
        help="add a device node (format is name:mode:uid:gid:c|b:maj:min)")

    parser.add_argument("--filter",
        dest="filters",
        action="append",
        default=[],
        metavar="FILTER",
        help="filter out some files from generated image")

    # ubi image specific options
    parser.add_argument("--mkubifs",
        dest="mkubifs",
        default=None,
        help="arguments to give to mkfs.ubifs")
    parser.add_argument("--ubinize",
        dest="ubinize",
        default=None,
        help="arguments to give to ubinize")
    parser.add_argument("--ubinize-root",
        dest="ubinizeRoot",
        default=None,
        help="directory where ubinize should be executed from")

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
