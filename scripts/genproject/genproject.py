#!/usr/bin/env python3

import sys
import os
import logging
import argparse
import subprocess
import importlib
import xml.parsers.expat

sys.path.append(os.path.join(os.path.dirname(__file__), ".."))
import moduledb

_PROJECT_KINDS = {"eclipse": None, "qtcreator": None, "jsondb": None}

_SOURCE_EXTENSIONS = [".c", ".cpp", ".cc", ".cxx"]
_HEADER_EXTENSIONS = [".h", ".hpp", ".hh", ".hxx"]

#===============================================================================
#===============================================================================
class Project(object):
    def __init__(self, name, modules, db, outdirpath, options):
        self.name = name
        self.modules = set(modules)
        self._db = db
        self.outdirpath = outdirpath
        self.options = options

        self.product = self.get_target_var("PRODUCT")
        self.variant = self.get_target_var("PRODUCT_VARIANT")
        self.staging_dir = self.get_target_var("OUT_STAGING")
        self.workspace_dir = self.get_target_var("ALCHEMY_WORKSPACE_DIR")


        # Construct build and clean command arguments
        self.build_dir = self.workspace_dir
        self.build_cmd = "./build.sh"
        self.build_args = options.custom_build_args
        self.build_target = ""
        self.clean_target = ""
        for module in self.modules:
            self.build_target += " " + module
            self.clean_target += " " + module + "-clean"

        # Construct run environment and command
        self.run_env = ""
        self.run_cmd = ""
        if self.get_target_var("OS_FLAVOUR") == "native":
            for module in self.modules:
                if self.get_module_class(module) == "EXECUTABLE":
                    self.run_env = "LD_LIBRARY_PATH=" + ":".join(
                            [os.path.join(self.staging_dir, x)
                                    for x in ["lib", "usr/lib"]])
                    self.run_cmd = os.path.join(self.staging_dir,
                            self.get_module_field(module, "DESTDIR"),
                            self.get_module_field(module, "MODULE_FILENAME"))
                    break

        # Compute dependencies
        self.depends = set()
        self.depends_all = set()
        self.depends_headers = set()
        for module in self.modules:
            module_depends = self._check_depends(module,
                    self.get_module_field(module, "depends").split())
            module_depends_all = self._check_depends(module,
                    self.get_module_field(module, "depends.all").split())
            module_depends_headers = self._check_depends(module,
                    self.get_module_field(module, "depends.headers").split())
            self.depends.update(module_depends)
            self.depends_all.update(module_depends_all)
            self.depends_headers.update(module_depends_headers)

        # Compute list of include directories
        self.includes = set()
        self.includes.update(self.get_target_var("GLOBAL_C_INCLUDES").split())
        for module in self.modules:
#            self.includes.add(self.get_module_build_dir(module))
            self.includes.add(self.get_module_field(module, "PATH"))
            self.includes.update(self.get_module_field(module, "C_INCLUDES").split())
            self.includes.update(self.get_module_field(module, "EXPORT_C_INCLUDES").split())
        for dep in self.depends_all | self.depends_headers:
            self.includes.update(self.get_module_field(dep, "EXPORT_C_INCLUDES").split())
            self.includes.update([x[2:]
                    for x in self.get_module_field(dep, "EXPORT_CFLAGS").split()
                    if x.startswith("-I")])

        # Compute list of autoconf files
        self.autoconf_h_files = set()
        for module in self.modules | self.depends_all:
            autoconf_h_file = self._get_module_autoconf_h_file(module)
            if autoconf_h_file is not None:
                if not os.path.exists(autoconf_h_file):
                    logging.warning("%s: missing autoconf.h file '%s'", module, autoconf_h_file)
                else:
                    self.autoconf_h_files.add(autoconf_h_file)

        # Compute CFLAGS
        self.cflags = set()
        self.cflags.update(self.get_target_var("GLOBAL_CFLAGS").split())
        for module in self.modules:
            self.cflags.update(self.get_module_field(module, "CFLAGS").split())
            self.cflags.update(self.get_module_field(module, "EXPORT_CFLAGS").split())
        for dep in self.depends_all:
            self.cflags.update(self.get_module_field(dep, "EXPORT_CFLAGS").split())

        # Compute CXXFLAGS
        self.cxxflags = set()
        self.cxxflags.update(self.get_target_var("GLOBAL_CXXFLAGS").split())
        for module in self.modules:
            self.cxxflags.update(self.get_module_field(module, "CXXFLAGS").split())
            self.cxxflags.update(self.get_module_field(module, "EXPORT_CXXFLAGS").split())
        for dep in self.depends_all:
            self.cxxflags.update(self.get_module_field(dep, "EXPORT_CXXFLAGS").split())

        # Compute defines for C/CXX
        self.defines_c = Project._get_defines(self.cflags)
        self.defines_cxx = Project._get_defines(self.cxxflags)
        for dep in self.depends_all:
            name = "BUILD_" + dep.replace("-", "_").replace(".", "_").upper()
            self.defines_c[name] = ""
            self.defines_cxx[name] = ""

        # Compute list of source files and headers
        self.sources = set()
        self.headers = set()
        if not options.list_files:
            for module in self.modules:
                module_root = self.get_module_field(module, "PATH")
                for src_file in self.get_module_field(module, "SRC_FILES").split():
                    self.sources.add(os.path.join(module_root, src_file))
                # Directories to search for headers
                # Do not include PATH to avoid finding too many false files
                module_includes = set()
                module_includes.update(self.get_module_field(module, "C_INCLUDES").split())
                module_includes.update(self.get_module_field(module, "EXPORT_C_INCLUDES").split())
                module_includes.update([os.path.dirname(x) for x in self.sources])
                for include in module_includes:
                    for dirpath, _, filenames in os.walk(include):
                        for filename in filenames:
                            extension = os.path.splitext(filename)[1]
                            if extension in _HEADER_EXTENSIONS:
                                self.headers.add(os.path.join(dirpath, filename))
        else:
            # First get a list of directories to process
            rootdirs = set()
            if options.list_files_root:
                for module_or_dir in options.modules_or_dirs:
                    if os.path.exists(module_or_dir):
                        rootdirs.add(os.path.abspath(module_or_dir))
            else:
                for module in self.modules:
                    module_root = self.get_module_field(module, "PATH")
                    rootdirs.add(module_root)
            # Get files found in directories
            for rootdir in rootdirs:
                if options.list_files == "fs":
                    for dirpath, _, filenames in os.walk(rootdir):
                        for filename in filenames:
                            self.sources.add(os.path.join(dirpath, filename))
                elif options.list_files == "git":
                    try:
                        files = subprocess.check_output(["git", "ls-files"],
                                cwd=rootdir,
                                universal_newlines=True).strip("\n").split("\n")
                        self.sources.update([os.path.join(rootdir, x) for x in files])
                    except subprocess.CalledProcessError as ex:
                        logging.warning("Failed to list files in '%s' (returncode=%d)",
                                rootdir, ex.returncode)

        # Dependencies to link
        self.linked_resources = {}
        if options.link_deps_full:
            depends =  self.depends_all | self.depends_headers
        elif options.link_deps:
            depends =  self.depends | self.depends_headers
        else:
            depends = set()
        for dep in depends:
            dep_path = self.get_module_src_dir(dep)
            # Exclude prebuilt and libboost
            if dep != "libboost" and \
                    dep_path is not None and \
                    not dep_path.startswith(self.outdirpath):
                self.linked_resources[dep] = dep_path

    @staticmethod
    def _get_defines(flags):
        defines = {}
        for flag in flags:
            if flag.startswith("-D"):
                if "=" in flag:
                    name, value = flag[2:].split("=", 1)
                else:
                    name, value = flag[2:], ""
                defines[name] = value
        return defines

    @staticmethod
    def _get_real_src_dir(src_dir):
        real_src_dir = src_dir
        (head, tail) = os.path.split(src_dir)
        if tail == "":
            (head, tail) = os.path.split(head)
        if tail.lower() == "build" or tail.lower() == "alchemy":
            real_src_dir = head
        return real_src_dir

    def _check_depends(self, module, depends):
        depends_ok = set()
        for dep in depends:
            if dep not in self._db:
                logging.warning("%s: unknown dependency %s", module, dep)
            else:
                depends_ok.add(dep)
        return depends_ok

    def _get_module_autoconf_h_file(self, module):
        filename = "autoconf-" + module + ".h"
        if "CONFIG_FILES" in self._db[module].fields:
            return os.path.join(self.get_module_build_dir(module), filename)
        else:
            return None

    def get_target_var(self, name, default=""):
        return self._db.targetVars.get(name, default)

    def get_module_field(self, module, field, default=""):
        return self._db[module].fields.get(field, default)

    def get_module_build_dir(self, module):
        return os.path.join(self.get_target_var("OUT_BUILD"), module)

    def get_module_class(self, module):
        return self.get_module_field(module, "MODULE_CLASS")

    def get_module_src_dir(self, module):
        archive = self.get_module_field(module, "ARCHIVE")
        archive_subdir = self.get_module_field(module, "ARCHIVE_SUBDIR")
        module_class = self.get_module_field(module, "MODULE_CLASS")
        if self.get_module_class(module) == "PREBUILT":
            return None
        elif archive and archive_subdir:
            return os.path.join(self.get_module_build_dir(module), archive_subdir)
        elif self.get_module_field(module, "GENERATED_SRC_FILES"):
            return self.get_module_build_dir(module)
        else:
            return Project._get_real_src_dir(self.get_module_field(module, "PATH"))

#===============================================================================
#===============================================================================
def main():
    # Load project specific packages
    for kind in _PROJECT_KINDS:
        _PROJECT_KINDS[kind] = importlib.import_module(kind)

    # Parse arguments
    options = parse_args()
    setup_log()

    # Load module db from xml
    try:
        db = moduledb.loadXml(options.dump_xml)
    except (OSError, xml.parsers.expat.ExpatError) as ex:
        logging.error("Error while loading '%s': %s", options.dump_xml, str(ex))
        sys.exit(1)

    # Construct the list of modules to generate
    modules = []
    for module_or_dir in options.modules_or_dirs:
        if os.path.exists(module_or_dir):
            dir_path = os.path.abspath(module_or_dir)
            for module in db.keys():
                module_path = os.path.abspath(db[module].fields["PATH"])
                if dir_path == module_path:
                    if module not in modules:
                        modules.append(module)
                elif options.recursive and module_path.startswith(dir_path + os.path.sep):
                    if module not in modules:
                        modules.append(module)
        elif module_or_dir in db:
            if module_or_dir not in modules:
                modules.append(module_or_dir)
        else:
            logging.error("Unknown module or directory: '%s'", module_or_dir)
            sys.exit(1)

    if len(modules) == 0:
        logging.warning("No module found")
        sys.exit(1)

    # Construct the list of projects to generate
    projects = []
    if options.merge:
        # Use first module for name and path if none given explicitly
        if not options.name:
            options.name = modules[0]
            logging.warning("Using '%s' for project name", options.name)
        if not options.outdirpath:
            options.outdirpath = os.path.abspath(db[modules[0]].fields["PATH"])
            logging.warning("Using '%s' for project output", options.outdirpath)
        projects.append(Project(options.name, modules, db, options.outdirpath, options))
    else:
        if len(modules) > 1 and options.name:
            logging.warning("Ignoring name option '%s' "
                    "when generating several projects", options.name)
            options.name = None
        if len(modules) > 1 and options.outdirpath:
            logging.warning("Ignoring output option '%s' "
                    "when generating several projects", options.outdirpath)
            options.outdirpath = None

        for module in modules:
            name = options.name or module
            outdirpath = options.outdirpath or os.path.abspath(db[module].fields["PATH"])
            projects.append(Project(name, modules, db, outdirpath, options))

    for project in projects:
        if not os.path.exists(project.outdirpath):
            logging.error("%s: output directory '%s' does not exists",
                    project.name, project.outdirpath)
        else:
            _PROJECT_KINDS[options.kind].generate(project)

#===============================================================================
# Setup option parser and parse command line.
#===============================================================================
def parse_args():
    # Setup parser
    parser = argparse.ArgumentParser()

    # Positional arguments
    parser.add_argument("kind",
            choices=sorted(_PROJECT_KINDS.keys()),
            help="Project kind to generate")
    parser.add_argument("dump_xml",
            help="Alchemy database xml dump file path")
    parser.add_argument("modules_or_dirs", nargs="+",
            help="Modules or directories to generate")

    # Main options
    parser.add_argument("-b", "--custom-build-args",
            dest="custom_build_args",
            default="",
            metavar="BUILDARGS",
            help="Custom build arguments (it assumes command is 'build.sh').")
    parser.add_argument("-m", "--merge",
            dest="merge",
            action="store_true",
            default=False,
            help="Merge all modules or directories in a single project.")
    parser.add_argument("-n", "--name",
            dest="name",
            default=None,
            help="Name of project (Only when a single project is created). "
                    "Default is based on module NAME.")
    parser.add_argument("-o", "--output",
            dest="outdirpath",
            default=None,
            metavar="DIR",
            help="Output directory (Only when a single project is created). "
                    "Default is based on module PATH.")
    parser.add_argument("-r", "--recursive",
            dest="recursive",
            action="store_true",
            default=False,
            help="When directories are given search them recursively.")
    parser.add_argument("--list-files",
            dest="list_files",
            choices=["fs", "git"],
            default=None,
            help="Use given method to list files. "
                    "Default is based on module SRC_FILES.")
    parser.add_argument("--list-files-root",
            dest="list_files_root",
            action="store_true",
            default=False,
            help="When directories are given with --list-files, use them as "
                    "root (default is to use root of modules found).")
    parser.add_argument("-d", "--link-dependencies",
            dest="link_deps",
            action="store_true",
            default=False,
            help="Link direct dependencies sources in project.")
    parser.add_argument("-f", "--link-dependencies-full",
            dest="link_deps_full",
            action="store_true",
            default=False,
            help="Link all dependencies sources in project.")

    # Project generator specific options
    for kind in sorted(_PROJECT_KINDS.keys()):
        title = "%s specific optional arguments" % kind
        group = parser.add_argument_group(title=title)
        _PROJECT_KINDS[kind].setup_argparse(group)

    # Parse arguments and check validity
    return parser.parse_args()

#===============================================================================
# Setup logging system.
#===============================================================================
def setup_log():
    logging.basicConfig(
            level=logging.INFO,
            format="[%(levelname)s] %(message)s",
            stream=sys.stderr)
    logging.addLevelName(logging.CRITICAL, "C")
    logging.addLevelName(logging.ERROR, "E")
    logging.addLevelName(logging.WARNING, "W")
    logging.addLevelName(logging.INFO, "I")
    logging.addLevelName(logging.DEBUG, "D")

#===============================================================================
#===============================================================================
if __name__ == "__main__":
    main()
