#!/usr/bin/env python3

import sys, os, logging
import argparse
import shutil
import fnmatch
import tarfile
import time
import xml.parsers
from io import StringIO

import moduledb

#===============================================================================
#===============================================================================
class Context(object):
    def __init__(self, options):
        self.dumpXmlPath = os.path.abspath(options.dumpXml)
        self.hostBuildDir = os.path.abspath(options.hostBuildDir)
        self.hostStagingDir = os.path.abspath(options.hostStagingDir)
        self.buildDir = os.path.abspath(options.buildDir)
        self.stagingDir = os.path.abspath(options.stagingDir)

        outDirOrArchive = os.path.abspath(options.outDirOrArchive)
        if outDirOrArchive.endswith(".tar.gz"):
            self.tarFile = tarfile.open(outDirOrArchive, "w:gz")
            self.outDir = "sdk"
        elif outDirOrArchive.endswith(".tar.bz2"):
            self.tarFile = tarfile.open(outDirOrArchive, "w:bz2")
            self.outDir = "sdk"
        elif outDirOrArchive.endswith(".tar"):
            self.tarFile = tarfile.open(outDirOrArchive, "w")
            self.outDir = "sdk"
        else:
            self.tarFile = None
            self.outDir = outDirOrArchive

        self.sdkDirs = []
        self.headerLibs = []
        self.files = {}

        # Load modules from xml
        logging.info("Loading xml '%s'", self.dumpXmlPath)
        try:
            self.moduledb = moduledb.loadXml(self.dumpXmlPath)
        except xml.parsers.expat.ExpatError as ex:
            sys.stderr.write("Error while loading '%s':\n" % self.dumpXmlPath)
            sys.stderr.write("  %s\n" % ex)
            sys.exit(1)

        self.atom = StringIO()
        self.atom.write("# GENERATED FILE, DO NOT EDIT\n\n")
        self.atom.write("LOCAL_PATH := $(call my-dir)\n\n")

        self.setup = StringIO()
        self.setup.write("# GENERATED FILE, DO NOT EDIT\n\n")
        self.setup.write("LOCAL_PATH := $(call my-dir)\n\n")

        if "OS_FLAVOUR" in self.moduledb.targetVars and \
                self.moduledb.targetVars["OS_FLAVOUR"] == "android":
            self.android = StringIO()
            self.android.write("# GENERATED FILE, DO NOT EDIT\n\n")
            self.android.write("LOCAL_PATH := $(call my-dir)\n\n")
        else:
            self.android = None

    def finishFile(self, fileData, fileName):
        if self.tarFile is not None:
            info = tarfile.TarInfo(os.path.join(self.outDir, fileName))
            info.size = fileData.tell()
            info.mtime = time.time()
            info.mode = 0o644
            info.type = tarfile.REGTYPE
            fileData.seek(0)
            self.tarFile.addfile(info, fileData)
        else:
            with open(os.path.join(self.outDir, fileName), "w") as fileObj:
                fileObj.write(fileData.getvalue())

    def finish(self):
        self.finishFile(self.atom, "atom.mk")
        self.finishFile(self.setup, "setup.mk")
        if self.android is not None:
            self.finishFile(self.android, "Android.mk")

    def addFile(self, srcFilePath, dstFilePath):
        if dstFilePath in self.files:
            return
        self.files[dstFilePath] = srcFilePath
        if self.tarFile is not None:
            if os.path.islink(srcFilePath):
                # Link file, ignore absolute links
                linkto = os.readlink(srcFilePath)
                if not os.path.isabs(linkto):
                    logging.debug("Link: '%s' -> '%s'", srcFilePath, dstFilePath)
                    self.tarFile.add(srcFilePath, arcname=dstFilePath)
            else:
                # Regular file
                logging.debug("Copy: '%s' -> '%s'", srcFilePath, dstFilePath)
                self.tarFile.add(srcFilePath, arcname=dstFilePath)
        else:
            # Create missing directories
            if not os.path.exists(os.path.dirname(dstFilePath)):
                os.makedirs(os.path.dirname(dstFilePath), mode=0o755)
            if os.path.islink(srcFilePath):
                # Link file, ignore absolute links
                if not os.path.lexists(dstFilePath):
                    linkto = os.readlink(srcFilePath)
                    if not os.path.isabs(linkto):
                        logging.debug("Link: '%s' -> '%s'", srcFilePath, dstFilePath)
                        os.symlink(linkto, dstFilePath)
            else:
                # Regular file, copy if source is newer in case destination exists
                if not os.path.lexists(dstFilePath):
                    doCopy = True
                else:
                    srcStat = os.stat(srcFilePath)
                    dstStat = os.stat(dstFilePath)
                    doCopy = srcStat.st_mtime > dstStat.st_mtime

                if doCopy:
                    logging.debug("Copy: '%s' -> '%s'", srcFilePath, dstFilePath)
                    shutil.copy2(srcFilePath, dstFilePath)

#===============================================================================
# Copy elements based on their extensions and limiting to a max depth if any
# If no extension is provided, any element will be took into account
#===============================================================================
def copyTree(ctx, srcDir, dstDir, includeExt=None, excludeExt=None, depth=-1):
    rootDepth = os.path.normpath(srcDir).count(os.sep)
    for (dirPath, dirNames, fileNames) in os.walk(srcDir):
        # Check depth of directory
        if depth >= 0:
            curDepth = os.path.normpath(dirPath).count(os.sep)
            if curDepth > rootDepth + depth:
                continue

        # A symlink to an existing directory is put in dirNames, not fileNames
        # fix this (use a copy in for loop because we will modify dirNames)
        for dirName in dirNames[:]:
            if os.path.islink(os.path.normpath(os.path.join(dirPath, dirName))):
                dirNames.remove(dirName)
                fileNames.append(dirName)

        for fileName in fileNames:
            # Include file ?
            if includeExt is None:
                include = True
            else:
                include = any([fnmatch.fnmatch(fileName, ext) for ext in includeExt])

            # Exclude file ?
            if excludeExt is None:
                exclude = False
            else:
                exclude = any([fnmatch.fnmatch(fileName, ext) for ext in excludeExt])

            # Process file if needed
            if include and not exclude:
                filePath = os.path.normpath(os.path.join(dirPath, fileName))
                relPath = os.path.relpath(filePath, srcDir)
                dstFilePath = os.path.normpath(os.path.join(dstDir, relPath))
                ctx.addFile(filePath, dstFilePath)

#===============================================================================
#===============================================================================
def copyHostStaging(ctx, srcDir, dstDir):
    logging.debug("Copy host staging: '%s' -> '%s'", srcDir, dstDir)
    exclude = ["*.la"]
    copyTree(ctx, srcDir, dstDir, excludeExt=exclude)

#===============================================================================
#===============================================================================
def copyStaging(ctx, srcDir, dstDir):
    logging.debug("Copy staging: '%s' -> '%s'", srcDir, dstDir)
    dirs_to_keep = ["lib",
        os.path.join("etc", "alternatives"),
        os.path.join("usr", "lib"),
        os.path.join("usr", "include"),
        os.path.join("usr", "share", "vala"),
        os.path.join("usr", "src", "linux-sdk"),
        os.path.join("usr", "local", "cuda-6.5"),
        os.path.join("usr", "local", "cuda-7.0"),
        os.path.join("system", "lib"),
        "host",
        "android",
        "toolchain",
        "opt",
    ]
    exclude = ["*.la"]
    for dirName in dirs_to_keep:
        srcDirPath = os.path.normpath(os.path.join(srcDir, dirName))
        if os.path.exists(srcDirPath):
            dstDirPath = os.path.normpath(os.path.join(dstDir, dirName))
            copyTree(ctx, srcDirPath, dstDirPath, excludeExt=exclude)

#===============================================================================
#===============================================================================
def copySdk(ctx, srcDir, dstDir):
    logging.debug("Copy sdk: '%s' -> '%s'", srcDir, dstDir)
    copyStaging(ctx, srcDir, dstDir)

#===============================================================================
#===============================================================================
def copyHeaders(ctx, srcDir, dstDir):
    logging.debug("Copy headers: '%s' -> '%s'", srcDir, dstDir)
    include = ["*.h", "*.hpp", "*.hh", "*.hxx", "*.doxygen", "*.inl", "*.ipp"]
    copyTree(ctx, srcDir, dstDir, includeExt=include)

#===============================================================================
#===============================================================================
def copyLibs(ctx, srcDir, dstDir):
    logging.debug("Copy libs: '%s' -> '%s'", srcDir, dstDir)
    include = ["*.a"]
    # Limit the copy to the base of the module
    copyTree(ctx, srcDir, dstDir, includeExt=include, depth=1)

#===============================================================================
# Remove symlinks whose target does not exists or is an absolute path.
#===============================================================================
def checkSymlinks(srcDir):
    logging.info("Checking symlinks")
    for (dirPath, dirNames, fileNames) in os.walk(srcDir):
        for fileName in fileNames:
            srcFilePath = os.path.join(dirPath, fileName)
            if not os.path.islink(srcFilePath):
                continue
            if not os.path.exists(srcFilePath):
                logging.info("Removing dangling symlink: '%s'", srcFilePath)
                os.unlink(srcFilePath)
            elif os.path.isabs(os.readlink(srcFilePath)):
                logging.info("Removing absolute symlink: '%s'", srcFilePath)
                os.unlink(srcFilePath)

#===============================================================================
#===============================================================================
def getExportedIncludes(ctx, module):
    modulePath = module.fields["PATH"]
    includeDirs = module.fields["EXPORT_C_INCLUDES"].split()
    exportedIncludeDirs = []
    suffixesInc = ["include", "includes", "Include", "Includes"]
    suffixesSrc = ["src", "source", "sources", "Source", "Sources"]
    shortName = module.name[3:] if module.name.startswith("lib") else module.name

    # Check if we can put exported directories directly in usr/include
    simplify = True
    for includeDir in includeDirs:
        isStandard = os.path.split(includeDir.rstrip("/"))[1] in suffixesInc
        if includeDir.startswith(modulePath):
            # Get entries in directory, excluding hidden ones
            entries = [f for f in os.listdir(includeDir) if not f.startswith('.')]
            for entry in entries:
                if os.path.isdir(os.path.join(includeDir, entry)):
                    # Reject if source tree seems to be exported
                    if entry in suffixesSrc:
                        simplify = False
                else:
                    # Reject if exporting files with name not related to module dir
                    # if not in a valid include directory
                    if shortName not in entry and not isStandard:
                        simplify = False

    for includeDir in includeDirs:
        if includeDir.startswith(modulePath):
            dstDir = None
            relPath = os.path.relpath(includeDir, modulePath)
            entries = [f for f in os.listdir(includeDir) if not f.startswith('.')]

            if simplify:
                dstDir = os.path.join("usr", "include")
            elif relPath != "." and relPath != "":
                dstDir = os.path.join("usr", "include", module.name,
                        relPath.replace("..", "dotdot"))
            else:
                dstDir = os.path.join("usr", "include", module.name)
            exportedIncludeDirs.append([includeDir, dstDir])
        elif includeDir.startswith(os.path.join(ctx.buildDir, module.name)):
            # TODO: simplify destination by remove extra 'include' and 'module name'
            relPath = os.path.relpath(includeDir, os.path.join(ctx.buildDir, module.name))
            if relPath != ".":
                dstDir = os.path.join("usr", "include", module.name,
                        relPath.replace("..", "dotdot"))
            else:
                dstDir = os.path.join("usr", "include", module.name)
            exportedIncludeDirs.append([includeDir, dstDir])
        elif includeDir.startswith(ctx.stagingDir + "/"):
            # No copy
            relPath = os.path.relpath(includeDir, ctx.stagingDir)
            exportedIncludeDirs.append([None, relPath])
        elif includeDir.startswith(ctx.hostStagingDir + "/"):
            # No copy
            relPath = os.path.relpath(includeDir, ctx.hostStagingDir)
            exportedIncludeDirs.append([None, os.path.join("host", relPath)])
        elif includeDir.startswith("/opt/"):
            # Assume it is a required host package installed externally
            exportedIncludeDirs.append([None, includeDir])
        else:
            logging.warning("Ignoring include dir: '%s'", includeDir)

    return exportedIncludeDirs

#===============================================================================
#===============================================================================
def processModule(ctx, module, headersOnly=False):
    # Skip module not built
    if not module.build and not headersOnly:
        return
    logging.info("Processing module %s", module.name)

    # Remember modules not built but whose headers are required
    if not headersOnly and "DEPENDS_HEADERS" in module.fields:
        libs = module.fields["DEPENDS_HEADERS"].split()
        for lib in libs:
            if lib not in ctx.headerLibs \
                    and lib in ctx.moduledb \
                    and not ctx.moduledb[lib].build:
                ctx.headerLibs.append(lib)

    # Start a new module
    ctx.atom.write("include $(CLEAR_VARS)\n")
    modulePath = module.fields["PATH"]
    moduleClass = module.fields["MODULE_CLASS"]

    if module.name.startswith("host."):
        ctx.atom.write("LOCAL_HOST_MODULE := %s\n" % module.name[5:])
    else:
        ctx.atom.write("LOCAL_MODULE := %s\n" % module.name)

    # Write verbatim some fields
    fields = ["DESCRIPTION", "CATEGORY_PATH",
            "REVISION", "REVISION_DESCRIBE", "REVISION_URL",
            "FORCE_WHOLE_STATIC_LIBRARY",
            "EXPORT_CFLAGS", "EXPORT_CXXFLAGS"]
    for field in fields:
        if field in module.fields and module.fields[field]:
            ctx.atom.write("LOCAL_%s := %s\n" % (field, module.fields[field]))

    # Libraries
    # If a module contains prelinked '.a' mentionned in its EXPORT_LDLIBS, copy
    # them and update the variable
    if not headersOnly and "EXPORT_LDLIBS" in module.fields:
        libs = module.fields["EXPORT_LDLIBS"].split()
        newLibs = []
        for lib in libs:
            if lib.startswith("-L" + modulePath):
                libDir = lib[2:]
                # TODO: simplify destination by remove extra 'lib' and 'module name'
                relPath = os.path.relpath(libDir, modulePath)
                if relPath != ".":
                    dstDir = os.path.join("usr", "lib", module.name, relPath)
                else:
                    dstDir = os.path.join("usr", "lib", module.name)
                # Copy libs and add new directory
                copyLibs(ctx, libDir, os.path.join(ctx.outDir, dstDir))
                newLibs.append("-L$(LOCAL_PATH)/" + dstDir)
            elif lib.startswith(ctx.stagingDir):
                # Some module directly reference a path in staging, simply update
                # path, normally the file is already copied
                relPath = os.path.relpath(lib, ctx.stagingDir)
                newLibs.append("$(LOCAL_PATH)/" + relPath)
            elif lib.startswith(modulePath) and lib.endswith(".a"):
                # lib is defined by its full name (abs dir + lib name)
                relPath = os.path.relpath(lib, modulePath)
                if relPath != ".":
                    dstPath = os.path.join("usr", "lib", module.name, relPath)
                else:
                    dstPath = os.path.join("usr", "lib", module.name)
                ctx.addFile(lib, os.path.join(ctx.outDir, dstPath))
                newLibs.append("$(LOCAL_PATH)/" + dstPath)
            else:
                newLibs.append(lib)
        # Write libs in a readable way
        ctx.atom.write("LOCAL_EXPORT_LDLIBS :=")
        for lib in newLibs:
            ctx.atom.write(" \\\n\t%s" % lib)
        ctx.atom.write("\n")

    # Custom variables
    if "EXPORT_CUSTOM_VARIABLES" in module.fields:
        modulePath = module.fields["PATH"]
        custom = module.fields["EXPORT_CUSTOM_VARIABLES"]
        # replace value of LOCAL_PATH by string "LOCAL_PATH"
        custom = custom.replace(modulePath, "$(LOCAL_PATH)")
        ctx.atom.write("LOCAL_EXPORT_CUSTOM_VARIABLES :=")
        ctx.atom.write(" \\\n\t%s" % custom)
        ctx.atom.write("\n")

    # Include directories
    if "EXPORT_C_INCLUDES" in module.fields:
        ctx.atom.write("LOCAL_EXPORT_C_INCLUDES :=")
        exportedIncludeDirs = getExportedIncludes(ctx, module)
        for exportedInclude in exportedIncludeDirs:
            if exportedInclude[0] is not None:
                copyHeaders(ctx, exportedInclude[0], os.path.join(ctx.outDir, exportedInclude[1]))
            if os.path.isabs(exportedInclude[1]):
                ctx.atom.write(" \\\n\t%s" % exportedInclude[1])
            elif exportedInclude[1] != "usr/include":
                ctx.atom.write(" \\\n\t$(LOCAL_PATH)/%s" % exportedInclude[1])
        ctx.atom.write("\n")

    # Config file
    # Note: for sdk modules, LOCAL_CONFIG_FILES will simply indicate that a
    # config file is present, reconfiguration will not be possible.
    if "CONFIG_FILES" in module.fields:
        configFileName = "%s.config" % module.name
        srcFilePath = os.path.join(ctx.buildDir, module.name, configFileName)
        dstFilePath = os.path.join(ctx.outDir, "config", configFileName)
        if os.path.exists(srcFilePath):
            ctx.addFile(srcFilePath, dstFilePath)
            ctx.atom.write("LOCAL_CONFIG_FILES := 1\n")
            ctx.atom.write("sdk.%s.config := $(LOCAL_PATH)/config/%s\n" % (
                    module.name, configFileName))
            ctx.atom.write("$(call load-config)\n")

    # Set LOCAL_LIBRARIES with the content of 'depends'
    if not headersOnly and "depends" in module.fields:
        ctx.atom.write("LOCAL_LIBRARIES := %s\n" % module.fields["depends"])

    # Register shared/static libraries as normal so we can manage dependencies
    # Other are simply put as prebuilt
    ctx.atom.write("LOCAL_SDK := $(LOCAL_PATH)\n")
    if moduleClass in ["SHARED_LIBRARY", "STATIC_LIBRARY", "LIBRARY"]:
        ctx.atom.write("LOCAL_DESTDIR := %s\n" % module.fields["DESTDIR"])
        ctx.atom.write("LOCAL_MODULE_FILENAME := %s\n" % module.fields["MODULE_FILENAME"])
        ctx.atom.write("include $(BUILD_%s)\n" % moduleClass)
    else:
        ctx.atom.write("include $(BUILD_PREBUILT)\n")

    # End of module
    ctx.atom.write("\n")

#===============================================================================
#===============================================================================
def processModuleAndroidInternal(ctx, module, name, libPath, kind):
    ctx.android.write("include $(CLEAR_VARS)\n")
    ctx.android.write("LOCAL_MODULE := %s\n" % name)
    ctx.android.write("LOCAL_SRC_FILES := $(LOCAL_PATH)/%s\n" % libPath)

    # Exported flags
    fields = {
        "EXPORT_CFLAGS": "EXPORT_CFLAGS",
        "EXPORT_CXXFLAGS": "EXPORT_CPPFLAGS",
    }
    for field in fields:
        if field[0] in module.fields and module.fields[field[0]]:
            ctx.android.write("LOCAL_%s := %s\n" % (field[1], module.fields[field[0]]))

    # Exported includes, always put 'usr/include'
    ctx.android.write("LOCAL_EXPORT_C_INCLUDES := $(LOCAL_PATH)/usr/include")
    if "EXPORT_C_INCLUDES" in module.fields:
        exportedIncludeDirs = getExportedIncludes(ctx, module)
        for exportedInclude in exportedIncludeDirs:
            if exportedInclude[0] is not None:
                copyHeaders(ctx, exportedInclude[0], os.path.join(ctx.outDir, exportedInclude[1]))
            if os.path.isabs(exportedInclude[1]):
                ctx.android.write(" \\\n\t%s" % exportedInclude[1])
            elif exportedInclude[1] != "usr/include":
                ctx.android.write(" \\\n\t$(LOCAL_PATH)/%s" % exportedInclude[1])
    ctx.android.write("\n")

    # End of module
    ctx.android.write("include $(PREBUILT_%s_LIBRARY)\n" % kind)
    ctx.android.write("\n")

#===============================================================================
#===============================================================================
def processModuleAndroid(ctx, module):
    # Ignore host modules
    if module.name.startswith("host.") or not module.build:
        return
    moduleClass = module.fields["MODULE_CLASS"]

    if moduleClass == "SHARED_LIBRARY":
        # SHARED
        libPath = module.fields["DESTDIR"] + "/" + module.fields["MODULE_FILENAME"]
        processModuleAndroidInternal(ctx, module, module.name, libPath, "SHARED")
    elif moduleClass == "STATIC_LIBRARY":
        # STATIC
        libPath = module.fields["DESTDIR"] + "/" + module.fields["MODULE_FILENAME"]
        processModuleAndroidInternal(ctx, module, module.name + "-static", libPath, "STATIC")
    elif moduleClass == "LIBRARY":
        # Both SHARED and STATIC
        libPath = module.fields["DESTDIR"] + "/" + module.fields["MODULE_FILENAME"]
        processModuleAndroidInternal(ctx, module, module.name, libPath, "SHARED")
        if libPath.endswith(".so"):
            libPath = libPath[:-3] + ".a"
            processModuleAndroidInternal(ctx, module, module.name + "-static", libPath, "STATIC")
    elif "EXPORT_LDLIBS" in module.fields:
        # register all exported libs
        libNames = module.fields["EXPORT_LDLIBS"].split()
        for libName in ("lib" + libName[2:] for libName in libNames if libName.startswith("-l")):
            moduleName = module.name + "-" + libName if len(libNames) > 1 else module.name
            libPathShared = None
            libPathStatic = None
            # Search shared/static lib path
            for libDir in "lib", "usr/lib":
                libPath = os.path.join(libDir, libName)
                if os.path.exists(os.path.join(ctx.stagingDir, libPath) + ".so"):
                    libPathShared = libPath + ".so"
                if os.path.exists(os.path.join(ctx.stagingDir, libPath) + ".a"):
                    libPathStatic = libPath + ".a"
            # Register
            if libPathShared is not None and libPathStatic is not None:
                # Both SHARED and STATIC
                processModuleAndroidInternal(ctx, module, moduleName, libPathShared, "SHARED")
                processModuleAndroidInternal(ctx, module, moduleName + "-static", libPathStatic, "STATIC")
            elif libPathShared is not None:
                # SHARED
                processModuleAndroidInternal(ctx, module, moduleName, libPathShared, "SHARED")
            elif libPathStatic is not None:
                # STATIC
                processModuleAndroidInternal(ctx, module, moduleName + "-static", libPathStatic, "STATIC")

#===============================================================================
#===============================================================================
def checkTargetVar(ctx, name):
    val = ctx.moduledb.targetVars.get(name, "")
    if val:
        ctx.atom.write("ifneq (\"$(TARGET_%s)\",\"%s\")\n" % (name, val))
        ctx.atom.write("  $(error This sdk is for TARGET_%s=%s)\n" % (name, val))
        ctx.atom.write("endif\n\n")

#===============================================================================
#===============================================================================
def writeTargetSetupVars(ctx, name, val):
    # Replace directory path referencing previous sdk or staging directory
    for dirPath in ctx.sdkDirs:
        val = val.replace(dirPath, "$(LOCAL_PATH)")
    val = val.replace(ctx.stagingDir, "$(LOCAL_PATH)")
    ctx.setup.write("TARGET_%s :=" % name)
    for field in val.split():
        if field.startswith("-"):
            ctx.setup.write(" \\\n\t%s" % field)
        else:
            ctx.setup.write(" %s" % field)
    ctx.setup.write("\n\n")

#===============================================================================
# Main function.
#===============================================================================
def main():
    options = parseArgs()
    setupLog(options)

    # Extract arguments
    ctx = Context(options)

    # List of previous sdk to merge with the new one
    ctx.sdkDirs = ctx.moduledb.targetVars.get("SDK_DIRS", "").split()

    # Setup output directory
    if ctx.tarFile is None:
        logging.info("Initializing output directory '%s'", ctx.outDir)
        if os.path.exists(ctx.outDir):
            shutil.rmtree(ctx.outDir)
        os.makedirs(ctx.outDir, mode=0o755)

    # Copy content of host staging directory
    if os.path.exists(ctx.hostStagingDir):
        logging.info("Copying host staging directory")
        copyHostStaging(ctx, ctx.hostStagingDir, os.path.join(ctx.outDir, "host"))

    # Copy content of staging directory
    logging.info("Copying staging directory")
    copyStaging(ctx, ctx.stagingDir, ctx.outDir)

    # Copy content of previous sdk
    for srcDir in ctx.sdkDirs:
        copySdk(ctx, srcDir, ctx.outDir)

    # Add some TARGET_XXX variables checks to make sure that the sdk is used
    # in the correct environment
    target_elements = [
        "OS", "OS_FLAVOUR",
        "ARCH", "CPU", "CC_VERSION", "CC_FLAVOUR", "TOOLCHAIN_TRIPLET",
        "LIBC", "DEFAULT_ARM_MODE", "FLOAT_ABI"
    ]
    for element_to_check in target_elements:
        checkTargetVar(ctx, element_to_check)

    # Save initial TARGET_SETUP_XXX variables as TARGET_XXX
    for var in ctx.moduledb.targetSetupVars.keys():
        val = ctx.moduledb.targetSetupVars.get(var, "")
        if val:
            writeTargetSetupVars(ctx, var, val)

    # Add special linux variables
    if "linux" in ctx.moduledb and ctx.moduledb["linux"].build:
        val = ctx.moduledb.targetVars.get("LINUX_CROSS", "")
        if val:
            writeTargetSetupVars(ctx, "LINUX_CROSS", val)
        ctx.setup.write("LINUX_DIR := $(LOCAL_PATH)/usr/src/linux-sdk\n\n")
        ctx.setup.write("LINUX_BUILD_DIR := $(LOCAL_PATH)/usr/src/linux-sdk\n\n")

    # Process modules
    for module in ctx.moduledb:
        processModule(ctx, module)
        if ctx.android is not None:
            processModuleAndroid(ctx, module)

    # Process modules not built but whose headers are required
    for lib in ctx.headerLibs:
        processModule(ctx, ctx.moduledb[lib], headersOnly=True)

    # Check  symlinks
    if ctx.tarFile is None:
        checkSymlinks(ctx.outDir)

    # Process custom macros
    for macro in ctx.moduledb.customMacros.values():
        ctx.atom.write("define %s\n" % macro.name)
        ctx.atom.write(macro.value)
        ctx.atom.write("\nendef\n")
        ctx.atom.write("$(call local-register-custom-macro,%s)\n" % macro.name)

    ctx.finish()

#===============================================================================
# Setup option parser and parse command line.
#===============================================================================
def parseArgs():
    # Setup parser
    parser = argparse.ArgumentParser()

    # Positional arguments
    parser.add_argument("dumpXml", help="Xml dump")
    parser.add_argument("hostBuildDir", help="Host build directory")
    parser.add_argument("hostStagingDir", help="Host staging directory")
    parser.add_argument("buildDir", help="build directory")
    parser.add_argument("stagingDir", help="Staging directory")
    parser.add_argument("outDirOrArchive", help="Output directory or archive")

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
