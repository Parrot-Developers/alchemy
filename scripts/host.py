#!/usr/bin/env python3

import sys
import platform

def getinfo(name):
    if name == "OS":
        val = platform.system().lower()
        if "msys" in val or "mingw" in val:
            return "windows"
        return val
    elif name == "ARCH":
        is64bit = platform.architecture()[0] == "64bit"
        val = platform.machine().lower()
        if val.startswith("arm") or val == "aarch64" or val == "arm64":
            return "aarch64" if is64bit else "arm"
        elif val in ["i386", "i686", "amd64", "x86_64"]:
            return "x64" if is64bit else "x86"
        else:
            sys.stderr.write("Unknown architecture: '%s'\n" % val)
            return "unknown"
    else:
        return None

if __name__ == "__main__":
    def main():
        if len(sys.argv) != 2:
            sys.stderr.write("Invalid number of arguments: %d\n" % (len(sys.argv) - 1))
            sys.exit(1)
        val = getinfo(sys.argv[1])
        if val is None:
            sys.stderr.write("Invalid argument '%s'\n" % sys.argv[1])
            sys.exit(1)
        print(val)
    main()
