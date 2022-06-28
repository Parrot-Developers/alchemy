#!/usr/bin/env python3

import argparse
import csv
import moduledb
import os
import re
import sys


# All Open-Source licenses
OPENSOURCE_LICENSES = [
    "AFL_AND_GPL",
    "APACHE2",
    "BSD",
    "BSD_LIKE",
    "BSD_2_CLAUSE",
    "BOOST",
    "ECOS_PUBLIC",
    "GPL",
    "GPL2",
    "GPL3",
    "ICU",
    "LGPL",
    "LGPL2",
    "LGPL3",
    "MIT",
    "MIT_LIKE",
    "MPL",
    "PUBLIC_DOMAIN",
    "PYTHON",
    "W3C",
    "ZLIB"]

class Context:
    _RE_CONFIGURE_VERSION = re.compile(r"PACKAGE_VERSION='(.*)'")
    _RE_CMAKE_VERSION = re.compile(r"project\(.*VERSION ([^\)]*)\)")
    _RE_LINUX_VERSION_MAJOR = re.compile(r"^VERSION = (.*)")
    _RE_LINUX_VERSION_MINOR = re.compile(r"^PATCHLEVEL = (.*)")
    _RE_LINUX_VERSION_LEVEL = re.compile(r"^SUBLEVEL = (.*)")
    _RE_MODULE_LICENSE = re.compile(r"^\.?MODULE_LICENSE_([^\.]*)$")

    def __init__(self, workspace, db):
        self.workspace = workspace
        self.db = db
        self.data = []

    def generate(self, output):
        for module in self.db:
            if not module.build:
                continue

            license = self.extract_license(module)
            if license in OPENSOURCE_LICENSES:
                license_kind = "OPENSOURCE"
            else:
                license_kind = "PROPRIETARY"
            version = self.extract_version(module)
            repo_url = module.fields["REVISION_URL"]
            repo_revision = module.fields["REVISION"]

            self.data.append({
                "name": module.name,
                "license": license,
                "license_kind": license_kind,
                "version": version,
                "repo_url": repo_url,
                "repo_revision": repo_revision,
            })

        if self.data:
            header = self.data[0].keys()
            writer = csv.DictWriter(output, header)
            writer.writeheader()
            writer.writerows(self.data)

    def extract_version(self, module):
        return module.fields.get("ARCHIVE_VERSION") or \
                self.extract_version_from_configure(module) or \
                self.extract_version_from_cmake(module) or \
                self.extract_version_from_linux(module) or \
                "UNKNOWN"

    def extract_version_from_configure(self, module):
        filepath = os.path.join(module.fields["PATH"], "configure")
        try:
            with open(filepath, "r") as fin:
                for line in fin:
                    match = Context._RE_CONFIGURE_VERSION.search(line)
                    if match:
                        return match.group(1)
        except:
            pass
        return None

    def extract_version_from_cmake(self, module):
        filepath = os.path.join(module.fields["PATH"], "CMakeLists.txt")
        try:
            with open(filepath, "r") as fin:
                for line in fin:
                    match = Context._RE_CMAKE_VERSION.search(line)
                    if match:
                        return match.group(1)
        except:
            pass
        return None

    def extract_version_from_linux(self, module):
        filepath = os.path.join(module.fields["PATH"], "Makefile")
        major, minor, level = None, None, None
        try:
            with open(filepath, "r") as fin:
                for line in fin:
                    match = Context._RE_LINUX_VERSION_MAJOR.search(line)
                    if match:
                        major = match.group(1)
                    match = Context._RE_LINUX_VERSION_MINOR.search(line)
                    if match:
                        minor = match.group(1)
                    match = Context._RE_LINUX_VERSION_LEVEL.search(line)
                    if match:
                        level = match.group(1)
        except:
            pass

        valid = all([x is not None for x in (major, minor, level)])
        return f"{major}.{minor}.{level}" if valid else None

    def extract_license(self, module):
        root_dir = self.find_git_root_dir(module) or self.workspace

        def find_license_file(dirpath):
            for entry in os.listdir(dirpath):
                match = Context._RE_MODULE_LICENSE.match(entry)
                if match:
                    return match.group(1)

            # Look in parent until root of git directory is reached
            if os.path.samefile(dirpath, root_dir) or \
                    os.path.dirname(dirpath) == dirpath:
                return None
            else:
                return find_license_file(os.path.dirname(dirpath))

        return find_license_file(module.fields["PATH"]) or "UNKNOWN"

    def find_git_root_dir(self, module):
        def find_git_dir(dirpath):
            gitdirpath = os.path.join(dirpath, ".git")
            if os.path.exists(gitdirpath):
                return dirpath

            # Look in parent until root of workspace reached
            if os.path.samefile(dirpath, self.workspace) or \
                    os.path.dirname(dirpath) == dirpath:
                return None
            else:
                return find_git_dir(os.path.dirname(dirpath))

        return find_git_dir(module.fields["PATH"])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("database",
        metavar="ALCHEMY_DATABASE_XML",
        help="Alchemy database xml file")
    parser.add_argument("-o", "--output",
        metavar="FILE",
        help="Output file name (default: stdout)")
    parser.add_argument("-w", "--workspace",
        metavar="DIR",
        default=os.getcwd(),
        help="Workspace root directory (default: current directory)")
    options = parser.parse_args()

    db = moduledb.loadXml(options.database)
    ctx = Context(options.workspace, db)

    if options.output:
        with open(options.output, "w") as fout:
            ctx.generate(fout)
    else:
        ctx.generate(sys.stdout)


if __name__ == "__main__":
    main()
