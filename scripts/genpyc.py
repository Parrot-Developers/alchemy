#!/usr/bin/env python3

import argparse
import logging
import os
import py_compile
import sys

#===============================================================================
#===============================================================================
def is_python_file(filepath):
    return not os.path.islink(filepath) and \
            os.path.isfile(filepath) and \
            os.path.splitext(filepath)[1] == ".py"


#===============================================================================
#===============================================================================
def compile_file(filepath, sysroot):
    logging.debug("Compiling '%s'", filepath)

    dstpath = filepath + "c"

    if sysroot:
        relpath = os.path.relpath(filepath, sysroot)
        runpath = os.path.join("/", relpath)
    else:
        runpath = filepath

    py_compile.compile(filepath, cfile=dstpath, dfile=runpath, doraise=True, optimize=2)

    # Apply original file time to generated one
    st = os.stat(filepath)
    os.utime(dstpath, ns=(st.st_atime_ns, st.st_mtime_ns))

#===============================================================================
# Main function.
#===============================================================================
def main():
    options = parse_args()
    setup_log(options)

    sysroot = options.sysroot and os.path.abspath(options.sysroot)

    try:
        for d in options.dirs:
            d = os.path.abspath(d)
            logging.info("Scanning directory: %s", d)
            for dirpath, dirnames, filenames in os.walk(d):
                for filename in filenames:
                    filepath = os.path.join(dirpath, filename)
                    if is_python_file(filepath):
                        compile_file(filepath, sysroot)
    except Exception as ex:
        logging.critical("Exception: %s", ex)
        sys.exit(1)


#===============================================================================
# Setup option parser and parse command line.
#===============================================================================
def parse_args():
    parser = argparse.ArgumentParser()

    parser.add_argument("dirs",
        nargs="+",
        metavar="DIR",
        help="Directory to scan recursively")

    parser.add_argument("--sysroot",
        metavar="DIR",
        help="System root prefix to remove from generated file names")

    parser.add_argument("-q",
        dest="quiet",
        action="store_true",
        default=False,
        help="be quiet")
    parser.add_argument("-v",
        dest="verbose",
        action="store_true",
        help="verbose output")

    return parser.parse_args()


#===============================================================================
# Setup logging system.
#===============================================================================
def setup_log(options):
    logging.basicConfig(
        level=logging.INFO,
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
    elif options.verbose:
        logging.getLogger().setLevel(logging.DEBUG)


if __name__ == "__main__":
    main()
