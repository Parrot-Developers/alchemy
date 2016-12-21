#!/usr/bin/env python3
#
# Compatibility script
#

import sys
import os
import subprocess

#===============================================================================
#===============================================================================
def main():
    cmd = [
        os.path.join(os.path.dirname(__file__), "genproject", "genproject.py"),
        "qtcreator",
    ]
    cmd.extend(sys.argv[1:])
    subprocess.call(cmd)

#===============================================================================
#===============================================================================
if __name__ == "__main__":
    main()
