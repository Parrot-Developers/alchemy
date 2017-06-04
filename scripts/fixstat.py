#!/usr/bin/env python3

import sys, os, logging
import argparse
import stat
import re

SPACE_PATTERN = re.compile(r"\s+")

DEFAULT_PERMISSIONS = [
    r"/lib/ld-.*\.so.*  0755    root    root", # Linker shall be executable
    r"/lib/.*/ld-.*\.so.*  0755    root    root", # Linker shall be executable
    r"/usr/lib/libc.so  0755    root    root", # Linker shall be executable (musl case)
    r"/sbin/.*        0755    root    root",
    r"/bin/.*         0755    root    root",
    r"/usr/sbin/.*    0755    root    root",
    r"/usr/bin/.*     0755    root    root",
    r".*              0644    root    root", # Default for all files
    r".*/             0755    root    root", # Default for all directories
]

#===============================================================================
#===============================================================================
class MyStat(object):
    def __init__(self, st):
        self.mode = st.st_mode
        self.uid = st.st_uid
        self.gid = st.st_gid

#===============================================================================
#===============================================================================
class Permission(object):
    def __init__(self):
        self.pattern = ""
        self.rePattern = None
        self.mode = 0
        self.uid = 0
        self.gid = 0
        self.isDefault = False

#===============================================================================
#===============================================================================
class Context(object):
    def __init__(self):
        self.users = {}
        self.groups = {}
        self.path_permissions = {}
        self.regex_permissions = []

#===============================================================================
# Parse a /etc/passwd or /etc/group file to extract a name <-> id mapping.
#===============================================================================
def parseIdFile(filePath, kind):
    ids = {}
    # Open file and scan it
    try:
        fd = open(filePath, "r")
        lineNum = 0
        for line in fd:
            lineNum += 1
            # Skip comments and empty lines
            line = line.rstrip("\n")
            if len(line) == 0 or line.startswith("#"):
                continue
            # Split fields of line
            fields = line.split(":")
            if len(fields) >= 3:
                try:
                    # Get name and id
                    name = fields[0]
                    _id = int(fields[2], base=10)
                    logging.info("%s %d:%s", kind, _id, name)
                    ids[name] = _id
                except ValueError as ex:
                    logging.error("%s:%d: %s", filePath, lineNum, ex)
            else:
                logging.warning("Skipping id line: %s", line)
        fd.close()
    except IOError as ex:
        logging.error("Failed to open file: %s [err=%d %s]",
                filePath, ex.errno, ex.strerror)
    return ids

#===============================================================================
# Parse a permission line.
#===============================================================================
def parsePermissionLine(ctx, filePath, lineNum, line, isDefault=False):
    try:
        # Split fields of line
        if line.startswith('"'):
            # support space in filename
            file_end = line.index('"', 1) + 1
            fields = [line[0:file_end]]
            fields.extend(re.sub(SPACE_PATTERN, " ", line[file_end:]).lstrip(' ').split(" "))
        else:
            fields = re.sub(SPACE_PATTERN, " ", line).split(" ")
        if len(fields) < 4:
            logging.warning("Skipping permission line: %s", line)
            return
        logging.info("permission %s %s %s %s",
                fields[0], fields[1], fields[2], fields[3])
        pattern = fields[0]
        # Real paths are enclosed by double quotes, else this
        # is a regex.
        isPath = pattern[0] == '"' and pattern[-1] == '"'
        perm = Permission()
        perm.isDefault = isDefault
        if not isPath:
            # Compile pattern in a regex (remove leading
            # '/' so that pattern matching is OK when
            # listing a local dir, trailing '/' is only
            # used to try match on directory only)
            perm.pattern = pattern
            perm.rePattern = re.compile(pattern.strip("/") + "$")
        # Decode mode
        perm.mode = int(fields[1], base=8)
        # Decode user
        if fields[2] not in ctx.users:
            raise ValueError("Unknown user %s" % fields[2])
        perm.uid = ctx.users[fields[2]]
        # Decode group
        if fields[3] not in ctx.groups:
            raise ValueError("Unknown group %s" % fields[3])
        perm.gid = ctx.groups[fields[3]]
        if isPath:
            ctx.path_permissions[pattern[1:-1].strip("/")] = perm
        else:
            ctx.regex_permissions.append(perm)
    except (ValueError, re.error) as ex:
        logging.error("%s:%d: %s", filePath, lineNum, ex)

#===============================================================================
# Parse a permissions file to extract file pattern and associated data.
#===============================================================================
def parsePermissionsFile(ctx, filePath):
    # Open file and scan it
    try:
        fd = open(filePath, "r")
        lineNum = 0
        for line in fd:
            lineNum += 1
            # Skip comments and empty lines
            line = line.rstrip("\n")
            if len(line) == 0 or line.startswith("#"):
                continue
            parsePermissionLine(ctx, filePath, lineNum, line)
        fd.close()
    except IOError as ex:
        logging.error("Failed to open file: %s [err=%d %s]",
                filePath, ex.errno, ex.strerror)

#===============================================================================
#===============================================================================
def fixstat(ctx, filePath, st):
    # At least root by default...
    st.uid = 0
    st.gid = 0
    # Search in paths dict
    if filePath in ctx.path_permissions:
        perm = ctx.path_permissions[filePath]
        st.mode = stat.S_IFMT(st.mode) | stat.S_IMODE(perm.mode)
        st.uid = perm.uid
        st.gid = perm.gid
        return st
    # Else, search for the first matching pattern
    for perm in ctx.regex_permissions:
        # Make sure pattern for directories are done on directories
        if perm.pattern.endswith("/") and not stat.S_ISDIR(st.mode):
            continue
        if not perm.pattern.endswith("/") and stat.S_ISDIR(st.mode):
            continue
        if perm.rePattern.match(filePath) is not None:
            # Update mode (except for link because it is useless)
            if not stat.S_ISLNK(st.mode):
                st.mode = stat.S_IFMT(st.mode) | stat.S_IMODE(perm.mode)
            # User/group
            st.uid = perm.uid
            st.gid = perm.gid
            return st
    # Nothing to do
    return st

#===============================================================================
# Main function.
#===============================================================================
def main():
    options = parseArgs()
    setupLog(options)

    ctx = Context()
    if options.userFile is not None:
        ctx.users = parseIdFile(options.userFile, "user")
    if options.groupFile is not None:
        ctx.groups = parseIdFile(options.groupFile, "group")

    for filePath in options.permissionsFiles:
        parsePermissionsFile(ctx, filePath)

    if options.useDefault:
        for line in DEFAULT_PERMISSIONS:
            parsePermissionLine(ctx, "", 0, line, True)

    # Read file names on stdin
    for line in sys.stdin:
        filePath = line.rstrip("\n")
        if filePath.startswith("./"):
            filePath = filePath[2:]
        st = fixstat(ctx, filePath, MyStat(os.lstat(filePath)))
        buf = "%s;mode=0%o;uid=%d;gid=%d" % (filePath, st.mode, st.uid, st.gid)
        logging.debug("%s", buf)
        sys.stdout.write(buf + "\n")

#===============================================================================
# Setup option parser and parse command line.
#===============================================================================
def parseArgs():
    parser = argparse.ArgumentParser()

    parser.add_argument("--user-file",
        dest="userFile",
        default=None,
        metavar="FILE",
        help="Path to etc/passwd file with user <-> uid mapping")
    parser.add_argument("--group-file",
        dest="groupFile",
        default=None,
        metavar="FILE",
        help="Path to etc/group file with group <-> group mapping")
    parser.add_argument("--use-default",
        dest="useDefault",
        action="store_true",
        default=False,
        help="Apply default rules")
    parser.add_argument("--permissions-file",
        dest="permissionsFiles",
        action="append",
        default=[],
        metavar="FILE",
        help="Path to permissions file. Several allowed")

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
