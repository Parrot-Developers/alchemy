#!/usr/bin/env python3

import sys, os, logging
import platform
import subprocess
import argparse
import tempfile
import re
import signal
import shutil
import difflib
import hashlib

import host

# Full path to this script
SCRIPT_PATH = os.path.dirname(os.path.abspath(__file__))

# 32-bit or 64-bit ?
HOST_OS = host.getinfo("OS")
HOST_ARCH = host.getinfo("ARCH")

# Possible actions
ACTION_CHECK = "check"
ACTION_UPDATE = "update"
ACTION_CONFIG = "config"
ACTIONS = [ACTION_CHECK, ACTION_UPDATE, ACTION_CONFIG]

# Possible user interfaces
UIS = ["qconf", "mconf", "nconf"]

# Field separator in argument
ARG_FIELD_SEP = "|"

# Suffix for temp files
TEMP_SUFFIX = ".alchemy"

# Title we want to display (also saved in config files)
KCONFIG_TITLE = "Alchemy Configuration"

# TARGET_xxx variables to get from environment and to add in config file
TARGET_VARIABLES = [
    "TARGET_PRODUCT",
    "TARGET_PRODUCT_VARIANT",
    "TARGET_OS",
    "TARGET_OS_FLAVOUR",
    "TARGET_LIBC",
    "TARGET_ARCH",
    "TARGET_CPU",
]

#===============================================================================
# Menu class.
#===============================================================================
class Menu:
    def __init__(self, parent, name):
        self.parent = parent
        self.name = name
        self.subMenus = []
        self.modules = []
        if parent is not None:
            parent.subMenus.append(self)

    # Get sub-menu having given name, creating it if needed
    def getSubMenu(self, name):
        for menu in self.subMenus:
            if menu.name == name:
                return menu
        return Menu(self, name)

    def __lt__(self, other):
        return self.name < other.name

    def sort(self):
        # Sort each sub-menu recursively, then list itself, then list of modules
        for subMenu in self.subMenus:
            subMenu.sort()
        self.subMenus.sort()
        self.modules.sort()

    def canSimplify(self):
        for subMenu in self.subMenus:
            if not subMenu.canSimplify():
                return False
        for module in self.modules:
            if not module.canSimplify():
                return False
        return True

    class Iterator:
        def __init__(self, menu):
            self.menu = menu
            self.idx1 = 0
            self.idx2 = 0

        def __iter__(self):
            return self

        def next(self):
            return self.__next__()
        def __next__(self):
            item = None
            # If first list is finished, use second list until its end
            if self.idx1 >= len(self.menu.subMenus):
                if self.idx2 >= len(self.menu.modules):
                    raise StopIteration()
                else:
                    item = self.menu.modules[self.idx2]
                    self.idx2 += 1
                    return item

            # If second list is finished, use first list until its end
            if self.idx2 >= len(self.menu.modules):
                if self.idx1 >= len(self.menu.subMenus):
                    raise StopIteration()
                else:
                    item = self.menu.subMenus[self.idx1]
                    self.idx1 += 1
                    return item

            # Use item that comes first
            item1 = self.menu.subMenus[self.idx1]
            item2 = self.menu.modules[self.idx2]
            if item1.name < item2.name:
                item = item1
                self.idx1 += 1
            else:
                item = item2
                self.idx2 += 1

            return item

    def __iter__(self):
        return self.Iterator(self)

    def __repr__(self):
        return "{name=%s,subMenus=%s,modules=%s}" % \
                (self.name, str(self.subMenus), str(self.modules))

#===============================================================================
# Encapsulate module information.
#===============================================================================
class Module:
    def __init__(self, arg):
        fields = arg.split(ARG_FIELD_SEP)
        self.name = fields[0]
        self.desc = fields[1]
        self.depends = fields[2].split()
        self.dependsCond = [pair.split(":") for pair in fields[3].split()]
        self.path = fields[4].rstrip("/")
        self.categoryPath = fields[5].rstrip("/")
        self.sdk = fields[6].rstrip("/")
        self.configPath = fields[7]
        self.configInPathList = fields[8:]
        # Remove from self.depends, conditionals from self.dependsCond
        # Remove CONFIG_ prefix from conditional
        for depCond in self.dependsCond:
            if depCond[1] in self.depends:
                self.depends.remove(depCond[1])
            if depCond[0].startswith("CONFIG_"):
                depCond[0] = depCond[0][7:]

    def __lt__(self, other):
        return self.name < other.name

    def canSimplify(self):
        return self.categoryPath == ""

    def __repr__(self):
        return ("{name=%s,desc=%s,depends=%s,dependsCond=%s,path=%s," + \
                "categoryPath=%s,configPath=%s,configInPathList=%s}") % \
                (self.name, self.desc, self.depends, self.dependsCond, self.path,
                self.categoryPath, self.configPath, str(self.configInPathList))

#===============================================================================
# Get the full path to a kconfig binary.
#===============================================================================
def getKconfigPath(name):
    binDir = os.path.join(SCRIPT_PATH, "../kconfig/bin-" + HOST_OS + "-" + HOST_ARCH)
    return os.path.join(binDir, name)

#===============================================================================
# Simplify tree of menus by moving up modules to first non-empty parent.
#===============================================================================
def simplifyMenuTree(menu):
    if not menu.canSimplify():
        return
    # If we have only one sub-menu and no modules, move up our sub-menu
    if len(menu.subMenus) == 1 and len(menu.modules) == 0:
        menu.modules = menu.subMenus[0].modules
        if menu.name != "":
            menu.name += "/" + menu.subMenus[0].name
        else:
            menu.name = menu.subMenus[0].name
        menu.subMenus = menu.subMenus[0].subMenus
        # Start again with this menu
        simplifyMenuTree(menu)

    # If we have no sub-menus and only one module, move up if no previous up
    # were done (name does not have '/' )
    if len(menu.subMenus) == 0 and len(menu.modules) == 1 \
            and menu.name.find("/") < 0 and menu.parent is not None:
        menu.parent.modules.append(menu.modules[0])
        menu.parent.subMenus.remove(menu)

    # Go down (make a copy of list before as we may change it)
    for subMenu in menu.subMenus[:]:
        simplifyMenuTree(subMenu)

#===============================================================================
# Build the tree of menus of modules.
# modules: list of modules to put in tree.
#===============================================================================
def buildMenuTree(modules):
    # Create root first
    menuRoot = Menu(None, "")
    for module in modules:
        # Skip modules from sdk
        if module.sdk:
            continue
        # Get path, split it in components
        if module.categoryPath != "":
            components = module.categoryPath.split("/")
        else:
            components = module.path.split("/")
        menu = menuRoot
        for component in components:
            # Get next sub-menu, creating it if needed
            menu = menu.getSubMenu(component)
        # Add module in this menu
        menu.modules.append(module)
    simplifyMenuTree(menuRoot)
    menuRoot.sort()
    return menuRoot

#===============================================================================
# Expand a list of strings as a string with items separated by comma.
#===============================================================================
def expandListStr(itemList):
    res = ""
    for item in itemList:
        res += item if (len(res) == 0) else (", " + item)
    return res

#===============================================================================
# Get the define value of a name. '-' are replaced by '_' then to upper case.
#===============================================================================
def getDefine(name):
    return name.replace("-", "_").upper()

#===============================================================================
# Print a message to stdout.
#===============================================================================
def message(msg, *args):
    sys.stdout.write(msg % args + "\n")

#===============================================================================
# Delete a file, silently ignoring error if it does not exists.
# path : file path to delete
#===============================================================================
def safeUnlink(path):
    try:
        os.unlink(path)
    except OSError:
        pass

#===============================================================================
# Rename a file, taking into account the fact that under Windows destination
# shall not exits to succeed.
# old : old path.
# new : new path.
#===============================================================================
def safeRename(old, new):
    if platform.system() == "Windows" and os.path.exists(new):
        safeUnlink(new)
    dirPath = os.path.dirname(new)
    if dirPath and not os.path.exists(dirPath):
        os.makedirs(dirPath)
    shutil.copy(old, new)
    safeUnlink(old)

#===============================================================================
# Create a file, creating missing directories if needed.
#===============================================================================
def safeCreateFile(path):
    dirPath = os.path.dirname(path)
    if dirPath and not os.path.isdir(dirPath):
        os.makedirs(dirPath)
    return open(path, "w", newline="\n")

#===============================================================================
# Get the path to use for config edition.
# path : original config path.
#
# When this script is executed in parallel on the same workspace, we need
# dedicated unique files because we will read again this file and delete it at
# the end, so it really is a temp file. Use pid, to separate processes and hash
# to separate path.
#===============================================================================
def getEditConfigPath(origPath):
    return os.path.join(tempfile.gettempdir(), "alchemy-%d-%s.new" %
            (os.getpid(), hashlib.md5(bytearray(origPath, "UTF-8")).hexdigest())) # IGNORE:E1101

#===============================================================================
# Get the path to use for config diff.
# path : original config path.
#
# This path is only used as a final output, and not read again, we don't need
# special case as getEditConfigPath
#===============================================================================
def getDiffConfigPath(origPath):
    return origPath + ".diff"

#===============================================================================
# Write a 'diff' file of a configuration after edition.
# configPath : original config path.
# diff : diff to write.
#===============================================================================
def writeDiffConfig(configPath, diff):
    try:
        diffFile = open(getDiffConfigPath(configPath), "w", newline="\n")
        diffFile.writelines(diff)
        diffFile.close()
    except IOError as ex:
        logging.error("Failed to create file: %s [err=%d %s]",
            getDiffConfigPath(configPath), ex.errno, ex.strerror)

#===============================================================================
# Find a module by its define name.
# modules : list of modules to search.
# moduleDefine : name of module to find in its 'define' form.
#===============================================================================
def findModule(modules, moduleDefine):
    for module in modules:
        if getDefine(module.name) == moduleDefine:
            return module
    return None

#===============================================================================
# Write the config.in file for the TARGET_xxx environment variables.
# outFile : output file object.
#===============================================================================
def writeTargetVarConfigIn(outFile):
    for var in TARGET_VARIABLES:
        val = os.getenv(var, "")
        outFile.write("config %s\n" % var)
        outFile.write("  string\n")
        outFile.write("  default '%s'\n" % val)
        outFile.write("\n")

#===============================================================================
# Write the config.in file for the SDK modules.
# outFile : output file object.
# modules : module list.
#===============================================================================
def writeSdkModulesConfigIn(outFile, modules):
    for module in modules:
        if module.sdk:
            outFile.write("config ALCHEMY_BUILD_%s\n" % getDefine(module.name))
            outFile.write("  bool\n")
            outFile.write("  default 'y'\n")
            outFile.write("\n")

#===============================================================================
# Write the config.in file for the full configuration. It recursively descends
# in menu to create the file.
# outFile : output file object.
# menu : menu to process.
#===============================================================================
def writeFullConfigIn(outFile, menu):
    # Start new menu
    if menu.name != "":
        outFile.write("menu '%s'\n" % menu.name)

    # Iterate over menu items (either sub-menus or modules)
    for item in menu:

        if isinstance(item, Menu):

            # Descend in sub-menu
            subMenu = item
            writeFullConfigIn(outFile, subMenu)

        elif isinstance(item, Module):

            # Process module
            module = item
            moduleDefine = getDefine(module.name)
            buildDefine = "ALCHEMY_BUILD_" + moduleDefine
            outFile.write("menuconfig %s\n" % buildDefine)

            outFile.write("  bool '%s'\n" % module.name)
            for dep in module.depends:
                outFile.write("  select ALCHEMY_BUILD_%s\n" % getDefine(dep))
            for depCond in module.dependsCond:
                if depCond[0] != "OPTIONAL":
                    outFile.write("  select ALCHEMY_BUILD_%s if %s\n" % \
                            (getDefine(depCond[1]), depCond[0]))
            outFile.write("  default n\n")
            outFile.write("  help\n")
            outFile.write("    Build %s\n" % module.name)
            if len(module.desc) != 0:
                outFile.write("    %s\n" % module.desc)
            outFile.write("\n")

            if len(module.configInPathList) > 0:
                outFile.write("if %s\n" % buildDefine)
                outFile.write("\n")
                outFile.write("config ALCHEMY_FILE_%s\n" % moduleDefine)
                outFile.write("  string\n")
                outFile.write("  default '%s'\n" % module.configPath)
                outFile.write("\n")
                for configInPath in module.configInPathList:
                    outFile.write("source \"%s\"\n" % configInPath)
                outFile.write("\n")
                outFile.write("config ALCHEMY_ENDFILE_%s\n" % moduleDefine)
                outFile.write("  string\n")
                outFile.write("  default ''\n")
                outFile.write("\n")
                outFile.write("endif\n")
                outFile.write("\n")

    # End of menu
    if menu.name != "":
        outFile.write("endmenu\n")

#===============================================================================
# Write the header of the config file.
# outFile : output file object.
# module : optional module this config belongs.
#===============================================================================
def writeConfigHeader(outFile, module=None):
    outFile.write("#\n")
    outFile.write("# Automatically generated file; DO NOT EDIT.\n")
    outFile.write("# %s\n" % KCONFIG_TITLE)
    outFile.write("#\n")

    # Add module name if given. Required because we add an extra menu entry
    # when editing a single module (see writeModuleConfigIn)
    if module is not None:
        outFile.write("\n")
        outFile.write("#\n")
        outFile.write("# %s\n" % module.name)
        outFile.write("#\n")

#===============================================================================
# Write TARGET_xxx variables in config file.
#===============================================================================
def writeConfigTargetVar(outFile):
    for var in TARGET_VARIABLES:
        val = os.getenv(var, "")
        outFile.write("CONFIG_%s=\"%s\"\n" % (var, val))

#===============================================================================
# Write SDK modules in config file.
# modules : module list.
#===============================================================================
def writeConfigSdkModules(outFile, modules):
    for module in modules:
        if module.sdk:
            outFile.write("CONFIG_ALCHEMY_BUILD_%s=y\n" % getDefine(module.name))

#===============================================================================
# Write a menu of module configuration. It recursively descend in the tree.
# outFile : output file object.
# menu : menu to write.
# mainConfig : main configuration file content.
#===============================================================================
def writeConfigMenu(outFile, menu, mainConfig):

    # Iterate over menu items (either sub-menus or modules)
    for item in menu:

        if isinstance(item, Menu):

            # Sub-menu
            subMenu = item
            writeConfigMenu(outFile, subMenu, mainConfig)

        elif isinstance(item, Module):

            # Module
            module = item
            moduleDefine = getDefine(module.name)
            moduleBuildDefine = "CONFIG_ALCHEMY_BUILD_" + moduleDefine
            moduleBuildDefineSet = moduleBuildDefine + "=y"
            moduleBuildDefineNotSet = "# " + moduleBuildDefine + " is not set"

            # Determine if module is set or not. Do NOT force a value if we
            # don't have one otherwise the UI will not see that there might be
            # some changes to save...
            if moduleBuildDefineNotSet in mainConfig:
                outFile.write(moduleBuildDefineNotSet + "\n")
            elif moduleBuildDefineSet in mainConfig:
                outFile.write(moduleBuildDefineSet + "\n")

            # However, always write module configuration. If module is enabled,
            # it will get the one we have. kconfig has been patched to handle
            # this use case without considering the config as not up to date.
            # (if some can be configured though)
            if len(module.configInPathList) > 0:
                moduleFileDefine = "CONFIG_ALCHEMY_FILE_" + moduleDefine
                moduleEndFileDefine = "CONFIG_ALCHEMY_ENDFILE_" + moduleDefine
                outFile.write("%s=\"%s\"\n" % \
                        (moduleFileDefine, module.configPath))
                # Read module configuration file
                moduleConfig = []
                try:
                    moduleConfigFile = open(module.configPath, "r")
                    moduleConfig = moduleConfigFile.read().split("\n")
                    moduleConfigFile.close()
                except IOError as ex:
                    # Display error inly if module was set...
                    if moduleBuildDefineSet in mainConfig:
                        logging.error("Failed to open file: %s [err=%d %s]",
                            module.configPath, ex.errno, ex.strerror)
                    else:
                        logging.debug("Failed to open file: %s [err=%d %s]",
                            module.configPath, ex.errno, ex.strerror)
                # Skip the 8 first lines, as well as empty last line
                # (header + extra menu added by generateModuleConfigIn)
                lastEmpty = (len(moduleConfig) > 0 and len(moduleConfig[-1]) == 0)
                for line in (moduleConfig[8:-1] if lastEmpty else moduleConfig[8:]):
                    outFile.write(line + "\n")
                outFile.write("%s=\"\"\n" % moduleEndFileDefine)

#===============================================================================
# Prepare the full configuration for edition.
# outFile : output file object.
# menu : root of menu with modules.
# mainConfigPath : main config path.
# modules : module list.
#===============================================================================
def prepareFullConfig(outFile, menu, mainConfigPath, modules):
    # Read main configuration file
    mainConfig = []
    try:
        mainConfigFile = open(mainConfigPath, "r")
        mainConfig = mainConfigFile.read().split("\n")
        mainConfigFile.close()
    except IOError as ex:
        logging.error("Failed to open file: %s [err=%d %s]",
            mainConfigPath, ex.errno, ex.strerror)

    # Write header followed by menus
    writeConfigHeader(outFile)
    writeConfigTargetVar(outFile)
    writeConfigMenu(outFile, menu, mainConfig)
    writeConfigSdkModules(outFile, modules)

#===============================================================================
# Process ful configuration after its edition.
# inFile : input file object.
# modules : list of modules.
# mainConfigPath : main config path.
#===============================================================================
def processFullConfig(inFile, modules, mainConfigPath):
    logging.debug("Processing full config")

    reConfigBuild = re.compile(r"(# )?CONFIG_ALCHEMY_BUILD_([^= ]*)[= ].*")
    reConfigFile = re.compile(r"CONFIG_ALCHEMY_FILE_([^= ]*)[= ].*")
    moduleStatus = {}
    module = None
    moduleConfigFile = None

    # Write modules configuration in their own file
    lineIdx = 0
    for line in inFile:
        line = line.rstrip("\n")
        # Determine if we are starting a new module
        if line.startswith("# CONFIG_ALCHEMY_BUILD_") \
                or line.startswith("CONFIG_ALCHEMY_BUILD_"):
            # Clear current module
            if moduleConfigFile is not None:
                moduleConfigFile.close()
            moduleConfigFile = None
            module = None
            # Get new module
            match = reConfigBuild.match(line)
            if match is None:
                logging.warning("Failed to extract module name from: %s", line)
            else:
                module = findModule(modules, match.group(2))
                if module is None:
                    logging.warning("Unknown module: %s", match.group(2))
                else:
                    logging.debug("New module: %s", module.name)
            if module is not None:
                moduleStatus[module.name] = not line.startswith("#")
        # Get the name of the configuration file for the module
        elif line.startswith("CONFIG_ALCHEMY_FILE_"):
            if moduleConfigFile is not None:
                moduleConfigFile.close()
            moduleConfigFile = None
            # Make sure it is for the current module...
            # It happens when a new module with a config file is not yet saved
            # in full config, its CONFIG_ALCHEMY_BUILD_ is not present but its
            # CONFIG_ALCHEMY_FILE_ is (see writeConfigMenu)
            match = reConfigFile.match(line)
            idx = line.find("=")
            if match is None:
                modulefile = None
                logging.warning("Failed to extract module name from: %s", line)
            else:
                modulefile = findModule(modules, match.group(1))

            idx = line.find("=")
            if idx >= 0:
                moduleConfigPath = line[idx+1:].strip("\"\'")
                logging.debug("New module config: %s", moduleConfigPath)
                if module != modulefile:
                    logging.debug("  disabled (not saved yet)")
                elif not moduleStatus[module.name]:
                    logging.debug("  disabled")
                else:
                    try:
                        moduleConfigFile = safeCreateFile(
                                getEditConfigPath(moduleConfigPath))
                        writeConfigHeader(moduleConfigFile, module)
                    except IOError as ex:
                        logging.error("Failed to create file: %s [err=%d %s]",
                                getEditConfigPath(moduleConfigPath),
                                ex.errno, ex.strerror)
        # End of file
        elif line.startswith("CONFIG_ALCHEMY_ENDFILE_"):
            if moduleConfigFile is not None:
                moduleConfigFile.close()
            moduleConfigFile = None
        elif moduleConfigFile is not None:
            moduleConfigFile.write(line + "\n")
        # Skip lines of disabled modules
        elif module is not None and not moduleStatus[module.name]:
            pass
        # Ignore empty lines and comments silently (almost)
        elif len(line) == 0 or line.startswith("#"):
            logging.debug("Skipping line: %s", line)
        # Skip lines for target variables
        elif line.startswith("CONFIG_TARGET_"):
            pass
        # The 4 first lines are the header, and are silently skipped
        elif lineIdx >= 4:
            logging.warning("Skipping line: %s", line)
        lineIdx += 1

    # Close file
    if moduleConfigFile is not None:
        moduleConfigFile.close()

    # Create main configuration file
    try:
        mainConfigFile = safeCreateFile(getEditConfigPath(mainConfigPath))
    except IOError as ex:
        logging.error("Failed to create file: %s [err=%d %s]",
            getEditConfigPath(mainConfigPath), ex.errno, ex.strerror)
        return
    writeConfigHeader(mainConfigFile)
    # Write modules in a sorted order to ease merge.
    for key in sorted(moduleStatus.keys()):
        module = findModule(modules, getDefine(key))
        # Skip modules from sdk
        if module and module.sdk:
            continue
        if moduleStatus[key]:
            mainConfigFile.write("CONFIG_ALCHEMY_BUILD_%s=y\n" % \
                    getDefine(key))
        else:
            mainConfigFile.write("# CONFIG_ALCHEMY_BUILD_%s is not set\n" % \
                    getDefine(key))
    mainConfigFile.close()

#===============================================================================
# Check if a configuration is up to date.
# name : name to display in log messages.
# configPath : current configuration name.
# ignoreCommented : ignore lines that add/removed commented settings.
# return a diff if config is not up to date, None otherwise.
#===============================================================================
def checkConfig(name, configPath, ignoreCommented):
    logging.debug("Checking %s config: %s", name, configPath)

    forceOK = False
    forceKO = False

    # Try to open new configuration file
    # If no new file, assume configuration is up to date
    try:
        newFile = open(getEditConfigPath(configPath), "r")
        newContent = newFile.readlines()
        newFile.close()
    except IOError:
        logging.debug("New %s config does not exist", name)
        newFile = None
        newContent = []
        forceOK = True

    # Try to open current configuration file
    # If no current file, assume configuration is not up to date
    try:
        currentFile = open(configPath, "r")
        currentContent = currentFile.readlines()
        currentFile.close()
    except IOError:
        logging.debug("Current %s config does not exist", name)
        currentFile = None
        currentContent = []

    # Compare content, we create a new list because unified_diff is a
    # generator and so can only be iterated once
    result = None
    diff = list(difflib.unified_diff(currentContent, newContent,
            configPath, getEditConfigPath(configPath)))
    for line in diff:
        # Skip header, line informations and context
        if line.startswith("+++ ") \
                or line.startswith("--- ") \
                or line.startswith("@@ ") \
                or line.startswith(" "):
            continue
        # Ignore added or removed lines that are commented
        elif ignoreCommented and ( \
                line.startswith("+#") or line.startswith("-#") or \
                line == "+\n" or line == "-\n"):
            continue
        # Config is not up to date
        else:
            result = diff

    # Force result if needed
    if forceOK:
        result = None
    elif forceKO:
        result = diff

    # Return result
    if result is None:
        logging.debug("%s config is up to date", name)
    else:
        logging.debug("%s config is not up to date", name)
    return result

#===============================================================================
# Update a configuration.
# name : name to display in log messages.
# configPath : current configuration name.
#===============================================================================
def updateConfig(name, configPath):
    logging.debug("Updating %s config: %s", name, configPath)

    # Check configuration, do NOT ignore commented lines for the update
    diff = checkConfig(name, configPath, False)
    if diff is None:
        # Delete new configuration
        logging.debug("Delete new %s config", name)
        safeUnlink(getEditConfigPath(configPath))
    else:
        # Move new configuration
        logging.debug("Move new %s config", name)
        safeRename(getEditConfigPath(configPath), configPath)
        message("%s config updated: %s", name, configPath)

#===============================================================================
# Check a module config.
# module : module to check.
# doWriteDiff : True to write a diff file in case of config mismatch.
# return True if config is up to date, False otherwise.
#===============================================================================
def checkModuleConfig(module, doWriteDiff):
    # Skip modules with nothing configurable
    if len(module.configInPathList) == 0:
        return True
    # Check config, ignore commented lines
    diff = checkConfig(module.name, module.configPath, True)
    if diff is not None and doWriteDiff:
        message("%s config is not up to date (%s), see diff in: %s",
                module.name, module.configPath,
                getDiffConfigPath(module.configPath))
        writeDiffConfig(module.configPath, diff)
    elif diff is not None:
        message("%s config is not up to date (%s)", module.name, module.configPath)
    logging.debug("Delete %s", getEditConfigPath(module.configPath))
    safeUnlink(getEditConfigPath(module.configPath))
    return diff is None

#===============================================================================
# Update a module config.
# module : module to update.
#===============================================================================
def updateModuleConfig(module):
    # Skip modules with nothing configurable
    if len(module.configInPathList) == 0:
        return
    updateConfig(module.name, module.configPath)

#===============================================================================
# Check the main config.
# mainConfigPath : main config path.
# doWriteDiff : True to write a diff file in case of config mismatch.
# return True if config is up to date, False otherwise.
#===============================================================================
def checkMainConfig(mainConfigPath, doWriteDiff):
    # Check config, ignore commented lines
    diff = checkConfig("main", mainConfigPath, True)
    if diff is not None and doWriteDiff:
        message("%s config is not up to date (%s), see diff in: %s",
            "main", mainConfigPath, getDiffConfigPath(mainConfigPath))
        writeDiffConfig(mainConfigPath, diff)
    elif diff is not None:
        message("%s config is not up to date (%s)", "main", mainConfigPath)
    logging.debug("Delete %s", getEditConfigPath(mainConfigPath))
    safeUnlink(getEditConfigPath(mainConfigPath))
    return diff is None

#===============================================================================
# Update the main config.
# mainConfigPath : main config path.
#===============================================================================
def updateMainConfig(mainConfigPath):
    updateConfig("main", mainConfigPath)

#===============================================================================
# Check the full config.
# modules : list of modules to check.
# mainConfigPath : main config path.
# doWriteDiff : True to write a diff file in case of config mismatch.
# return True if config is up to date, False otherwise.
#===============================================================================
def checkFullConfig(modules, mainConfigPath, doWriteDiff):
    logging.debug("Checking full config")
    result = True

    # Check everything
    result = checkMainConfig(mainConfigPath, doWriteDiff) and result
    for module in modules:
        result = checkModuleConfig(module, doWriteDiff) and result
    return result

#===============================================================================
# Update the full config.
# modules : list of modules to update.
# mainConfigPath : main config path.
#===============================================================================
def updateFullConfig(modules, mainConfigPath):
    logging.debug("Updating full config")

    # Update everything
    updateMainConfig(mainConfigPath)
    for module in modules:
        updateModuleConfig(module)

#===============================================================================
# Execute 'conf' to silently update a configuration.
# configInPath : path to 'config.in' file.
# configPath : path to '.config' file.
#===============================================================================
def execConf(configInPath, configPath):
    logging.info("Executing conf %s %s", configInPath, configPath)

    # Construct command line
    if configInPath:
        cmdline = "%s --oldconfig %s" % (getKconfigPath("conf"), configInPath)
    else:
        cmdline = "%s --alldefconfig" % (getKconfigPath("conf"))

    # Setup environment
    # KCONFIG_CONFIG : name of .config file to use as input/ouput
    # KCONFIG_OVERWRITECONFIG : do not create .old file
    # KCONFIG_TITLE : set title (also saved in config file)
    env = os.environ
    env["KCONFIG_CONFIG"] = configPath
    env["KCONFIG_OVERWRITECONFIG"] = "1"
    env["KCONFIG_TITLE"] = KCONFIG_TITLE

    # Execute command in silence (stdout/stderr redirected and not used), piping
    # 'yes' as input to simulate accepting all new options to their default values
    try:
        yes = subprocess.Popen("yes ''",
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            shell=True, env=env)
        process = subprocess.Popen(cmdline,
            stdin=yes.stdout,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            shell=True, env=env)
        yes.stdout.close()
        process.communicate()
        yes.terminate()
        if process.returncode != 0:
            logging.error("%s failed with status %d", cmdline, process.returncode)
    except OSError as ex:
        logging.error("Failed to execute command: %s [err=%d %s]",
            cmdline, ex.errno, ex.strerror)

#===============================================================================
# Execute 'xconf' to edit a configuration in a user interface.
# confUi : user interface program to use.
# configInPath : path to 'config.in' file.
# configPath : path to '.config' file.
#===============================================================================
def execConfUi(confUi, configInPath, configPath):
    logging.info("Executing %s %s %s", confUi, configInPath, configPath)

    # Construct command line
    cmdline = "%s %s" % (getKconfigPath(confUi), configInPath)

    # Setup environment
    # KCONFIG_CONFIG : name of .config file to use as input/ouput
    # KCONFIG_OVERWRITECONFIG : do not create .old file
    # KCONFIG_TITLE : set title (also saved in config file)
    env = os.environ
    env["KCONFIG_CONFIG"] = configPath
    env["KCONFIG_OVERWRITECONFIG"] = "1"
    env["KCONFIG_TITLE"] = KCONFIG_TITLE

    # Execute command (we can not redirect input/output in case UI
    # is mconf or nconf)
    try:
        process = subprocess.Popen(cmdline,
            shell=True, env=env)
        process.communicate()
        if process.returncode != 0:
            logging.error("%s failed with status %d", cmdline, process.returncode)
    except OSError as ex:
        logging.error("Failed to execute command: %s [err=%d %s]",
            cmdline, ex.errno, ex.strerror)

#===============================================================================
# Main function.
#===============================================================================
def main():
    result = True
    options = parseArgs()
    setupLog(options)

    # Extract arguments
    action = options.action
    modules = [Module(_mod) for _mod in options.modules]

    # Build tree of menus of modules
    menuRoot = buildMenuTree(modules)

    # Create 'config.in' file
    (configInFd, configInPath) = tempfile.mkstemp(suffix=TEMP_SUFFIX)
    configInFile = os.fdopen(configInFd, "w", newline="\n")
    logging.info("Generating full 'config.in' file as %s", configInPath)
    writeTargetVarConfigIn(configInFile)
    writeFullConfigIn(configInFile, menuRoot)
    writeSdkModulesConfigIn(configInFile, modules)
    configInFile.close()

    # Create full '.config' file
    (fullConfigFd, fullConfigPath) = tempfile.mkstemp(suffix=TEMP_SUFFIX)
    fullConfigFile = os.fdopen(fullConfigFd, "w", newline="\n")
    logging.info("Generating full '.config' file as %s", fullConfigPath)
    prepareFullConfig(fullConfigFile, menuRoot, options.main, modules)
    fullConfigFile.close()

    # Cleanup function (in main context)
    def cleanup():
        logging.info("Cleanup before exit")
        # Delete temp files
        safeUnlink(configInPath)
        safeUnlink(fullConfigPath)
        # Delete all module edition files
        for module in modules:
            if len(module.configInPathList) > 0:
                safeUnlink(getEditConfigPath(module.configPath))

    # signal handler (in main context)
    def signalHandler(sig, _frame):
        logging.info("Signal %d caught", sig)
        cleanup()
        sys.exit(1)

    # Register signals to cleanup in case we are interrupted below
    signal.signal(signal.SIGINT, signalHandler)
    signal.signal(signal.SIGTERM, signalHandler)

    # Display UI or execute action in silence
    if action == ACTION_CONFIG:
        execConfUi(options.ui, configInPath, fullConfigPath)
    else:
        execConf(configInPath, fullConfigPath)

    # Process resulting full config
    configFullFile = open(fullConfigPath, "r")
    processFullConfig(configFullFile, modules, options.main)
    configFullFile.close()

    # Check/Update result
    if action == ACTION_CHECK:
        result = checkFullConfig(modules, options.main, options.diff)
    else:
        updateFullConfig(modules, options.main)

    # Do some cleanup and then exit with status=1 in case checking failed
    cleanup()
    sys.exit(0 if result else 1)

#===============================================================================
# Setup option parser and parse command line.
#===============================================================================
def parseArgs():
    # By default, ArgumentParser assumes an argument begining with '@' contains
    # actual arguments, one per line. Override default behavior to handle single
    # line with shell escaped argument list
    class MyArgumentParser(argparse.ArgumentParser):
        def convert_arg_line_to_args(self, arg_line):
            import shlex
            return shlex.split(arg_line)

    # Setup parser, handle arguments begining with '@' as a file containing
    # actual argument (to bypass command line size limits)
    parser = MyArgumentParser(fromfile_prefix_chars="@")

    # Positional arguments
    parser.add_argument("action",
            choices=ACTIONS,
            help="Action to execute")

    parser.add_argument("modules",
            nargs="*",
            help="Modules")

    # Main options
    parser.add_argument("--main",
        dest="main",
        action="store",
        metavar="FILE",
        required=True,
        help="Name of main configuration file")
    parser.add_argument("--diff",
        dest="diff",
        action="store_true",
        default=False,
        help="Write diff file if configuration is not up to date after check")
    parser.add_argument("--ui",
        dest="ui",
        default="qconf",
        choices=UIS,
        help="User interface to use (default is qconf)")

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
