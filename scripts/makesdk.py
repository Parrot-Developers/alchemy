#!/usr/bin/env python3

from os import path
import sys, os, logging
import argparse
import shutil
import subprocess
import fnmatch
import tarfile
import tempfile
import time
import xml.parsers
from io import StringIO

import moduledb

#===============================================================================
# Determine if a file should be stripped.
# - Elf file
# - Windows binaries
# - ar archive files
#===============================================================================
def shouldStrip(filePath):
    # FIXME: Disabled, it breaks a lot of things (at generation and use)
    # try:
    #     with open(filePath, "rb") as fd:
    #         hdr = fd.read(7)
    #         if hdr[:4] == b"\x7fELF" or hdr[:2] == b"MZ" or hdr[:7] == b"!<arch>":
    #             return True
    # except IOError as ex:
    #     logging.error("Failed to open file: %s ([err=%d] %s)",
    #         filePath, ex.errno, ex.strerror)
    return False

#===============================================================================
#===============================================================================
def stripFile(stripProg, srcFilePath, dstFilePath):
    # stripProg may already contains some arguments
    cmd = "%s -o %s %s" % (stripProg, dstFilePath, srcFilePath)
    try:
        subprocess.check_call(cmd, shell=True)
        return True
    except subprocess.CalledProcessError as ex:
        logging.exception(ex)
        return False

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
        self.moduleList = None
        self.privateFiles = None

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
            abi = os.path.basename(os.path.dirname(self.buildDir))
            self.android = StringIO()
            self.android.write("# GENERATED FILE, DO NOT EDIT\n\n")
            self.android.write("ifndef ALCHEMY_SDK_ANDROID_{}_INCLUDED\n".format(abi))
            self.android.write("ALCHEMY_SDK_ANDROID_{}_INCLUDED = 1\n\n".format(abi))
            self.android.write("LOCAL_PATH := $(call my-dir)\n\n")
            self.android_static = StringIO()
            self.android_static.write("# GENERATED FILE, DO NOT EDIT\n\n")
            self.android_static.write("ifndef ALCHEMY_SDK_ANDROID_STATIC_{}_INCLUDED\n".format(abi))
            self.android_static.write("ALCHEMY_SDK_ANDROID_STATIC_{}_INCLUDED = 1\n\n".format(abi))
            self.android_static.write("LOCAL_PATH := $(call my-dir)\n\n")
        else:
            self.android = None
            self.android_static = None

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
            self.android.write("include $(LOCAL_PATH)/Android-static.mk\n\n")
            self.android.write("endif\n")
            self.finishFile(self.android, "Android.mk")
        if self.android_static is not None:
            self.android_static.write("endif\n")
            self.finishFile(self.android_static, "Android-static.mk")

    def _addFile(self, srcFilePath, dstFilePath, origSrcFilePath):
        if dstFilePath in self.files:
            return

        self.files[dstFilePath] = srcFilePath
        if self.tarFile is not None:
            if os.path.islink(srcFilePath):
                # Link file, ignore absolute links
                linkto = os.readlink(srcFilePath)
                if not os.path.isabs(linkto):
                    logging.debug("Link: '%s' -> '%s'", origSrcFilePath, dstFilePath)
                    self.tarFile.add(srcFilePath, arcname=dstFilePath)
            else:
                # Regular file
                logging.debug("Copy: '%s' -> '%s'", origSrcFilePath, dstFilePath)
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
                        logging.debug("Link: '%s' -> '%s'", origSrcFilePath, dstFilePath)
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
                    logging.debug("Copy: '%s' -> '%s'", origSrcFilePath, dstFilePath)
                    shutil.copy2(srcFilePath, dstFilePath)

    def addFile(self, srcFilePath, dstFilePath):
        if shouldStrip(srcFilePath):
            stripProg = self.getStripProg(srcFilePath)
            try:
                tmpFileFd, tmpFilePath = tempfile.mkstemp()
                logging.debug("Strip: '%s'", srcFilePath)
                if stripFile(stripProg, srcFilePath, tmpFilePath):
                    self._addFile(tmpFilePath, dstFilePath, srcFilePath)
                else:
                    self._addFile(srcFilePath, dstFilePath, srcFilePath)
            finally:
                os.close(tmpFileFd)
                try:
                    os.unlink(tmpFilePath)
                except OSError:
                    pass
        else:
            self._addFile(srcFilePath, dstFilePath, srcFilePath)

    def isPublicFile(self, filePath):
        relPath = os.path.relpath(filePath, self.stagingDir)
        return relPath not in self.privateFiles

    def getStripProg(self, srcFilePath):
        if srcFilePath.startswith(self.hostStagingDir):
            return "strip -s"
        else:
            return self.moduledb.targetVars.get("STRIP", "strip -s")

#===============================================================================
# Copy elements based on their extensions and limiting to a max depth if any
# If no extension is provided, any element will be took into account
#===============================================================================
def copyTree(ctx, srcDir, dstDir, includeExt=None, excludeExt=None, depth=-1, publicOnly=False):
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
                if not publicOnly or ctx.isPublicFile(filePath):
                    ctx.addFile(filePath, dstFilePath)

#===============================================================================
#===============================================================================
def copyHostStaging(ctx, srcDir, dstDir):
    logging.debug("Copy host staging: '%s' -> '%s'", srcDir, dstDir)
    exclude = ["*.la"]
    copyTree(ctx, srcDir, dstDir, excludeExt=exclude)

#===============================================================================
#===============================================================================
def copyStaging(ctx, srcDir, dstDir, publicOnly=False):
    logging.debug("Copy staging: '%s' -> '%s'", srcDir, dstDir)
    dirs_to_keep = ["lib",
        os.path.join("etc", "alternatives"),
        os.path.join("usr", "lib"),
        os.path.join("usr", "include"),
        os.path.join("usr", "share"),
        os.path.join("usr", "src", "linux-sdk"),
        os.path.join("usr", "local", "cuda-6.5"),
        os.path.join("usr", "local", "cuda-7.0"),
        os.path.join("system", "lib"),
        "missions",
        "host",
        "android",
        "toolchain",
        "opt",
    ]
    exclude = ["*.la"]

    if ctx.moduledb.targetVars.get("OS", "") == "windows":
        dirs_to_keep.append("bin")
        dirs_to_keep.append(os.path.join("usr", "bin"),)
        exclude.append("*.exe")

    for dirName in dirs_to_keep:
        srcDirPath = os.path.normpath(os.path.join(srcDir, dirName))
        if os.path.exists(srcDirPath):
            dstDirPath = os.path.normpath(os.path.join(dstDir, dirName))
            copyTree(ctx, srcDirPath, dstDirPath, excludeExt=exclude, publicOnly=publicOnly)

#===============================================================================
#===============================================================================
def copySdk(ctx, srcDir, dstDir):
    logging.debug("Copy sdk: '%s' -> '%s'", srcDir, dstDir)
    copyTree(ctx, os.path.join(srcDir, "config"), os.path.join(dstDir, "config"))
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

    if module.name.endswith("legacy"):
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
PUBLIC_DEPS_FIELDS = [
    "STATIC_PUBLIC_LIBRARIES",
    "WHOLE_STATIC_PUBLIC_LIBRARIES",
    "SHARED_PUBLIC_LIBRARIES",
    "EXTERNAL_PUBLIC_LIBRARIES",
    "PREBUILT_PUBLIC_LIBRARIES",
    "PUBLIC_LIBRARIES",
]
PRIVATE_DEPS_FIELDS = [
    "STATIC_PRIVATE_LIBRARIES",
    "WHOLE_STATIC_PRIVATE_LIBRARIES",
    "SHARED_PRIVATE_LIBRARIES",
    "EXTERNAL_PRIVATE_LIBRARIES",
    "PREBUILT_PRIVATE_LIBRARIES",
    "PRIVATE_LIBRARIES",
    "DEPENDS_MODULES",
]
_publicDepsWarnList = set()
def getPublicDeps(module):
    # To determine if a conditional dependency is actually used, check if it is
    # found in 'direct' dependencies
    def getConditionalDeps(module, field):
        directDeps = module.fields.get("depends", "").split()
        condDeps = [dep.split(":")[1] for dep in module.fields.get(field, "").split()]
        return [dep for dep in condDeps if dep in directDeps]

    def getRawPublicDeps(module):
        publicDeps = " ".join([module.fields.get(field, "") for field in PUBLIC_DEPS_FIELDS]).split()
        condDeps = getConditionalDeps(module, "CONDITIONAL_PUBLIC_LIBRARIES")
        return publicDeps + condDeps

    def getRawPrivateDeps(module):
        privateDeps = " ".join([module.fields.get(field, "") for field in PRIVATE_DEPS_FIELDS]).split()
        condDeps = getConditionalDeps(module, "CONDITIONAL_PRIVATE_LIBRARIES")
        return privateDeps + condDeps

    def getDirectDeps(module):
        return module.fields.get("depends", "").split()

    rawPublicDeps = getRawPublicDeps(module)
    rawPrivateDeps = getRawPrivateDeps(module)
    directDeps = getDirectDeps(module)

    if not rawPublicDeps and not rawPrivateDeps and directDeps:
        if module not in _publicDepsWarnList:
            logging.warning("Module '%s' has no explicit public/private dependencies", module.name)
            _publicDepsWarnList.add(module)
        return directDeps
    else:
        return rawPublicDeps

#===============================================================================
#===============================================================================
def processModule(ctx, module, headersOnly=False, publicOnly=False):
    # Skip module from sdk
    if module.fields.get("SDK", ""):
        return

    # Skip builtin modules (but keep libc)
    if module.fields.get("BUILTIN", "") == "1" and module.name != "libc":
        return

    isHostModule = module.name.startswith("host.")

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

    if isHostModule:
        ctx.atom.write("LOCAL_HOST_MODULE := %s\n" % module.name[5:])
        outIncludeDir = os.path.join(ctx.outDir, "host")
    else:
        ctx.atom.write("LOCAL_MODULE := %s\n" % module.name)
        outIncludeDir = ctx.outDir

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
                copyHeaders(ctx, exportedInclude[0], os.path.join(outIncludeDir, exportedInclude[1]))
            if os.path.isabs(exportedInclude[1]):
                ctx.atom.write(" \\\n\t%s" % exportedInclude[1])
            elif exportedInclude[1] != "usr/include" or moduleClass == "LINUX_MODULE":
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

    # Set LOCAL_LIBRARIES with the content of public dependencies only
    if not headersOnly:
        deps = getPublicDeps(module) if publicOnly else module.fields.get("depends", "").split()
        if deps:
            ctx.atom.write("LOCAL_LIBRARIES := %s\n" % " ".join(deps))

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
def processModuleAndroidInternal(ctx, writer, module, name, libPath, kind):
    writer.write("include $(CLEAR_VARS)\n")
    writer.write("LOCAL_MODULE := %s\n" % name)
    writer.write("LOCAL_SRC_FILES := $(LOCAL_PATH)/%s\n" % libPath)

    # Exported flags
    fields = {
        "EXPORT_CFLAGS": "EXPORT_CFLAGS",
        "EXPORT_CXXFLAGS": "EXPORT_CPPFLAGS",
    }
    for field in fields:
        if field[0] in module.fields and module.fields[field[0]]:
            writer.write("LOCAL_%s := %s\n" % (field[1], module.fields[field[0]]))

    # Exported includes, always put 'usr/include'
    writer.write("LOCAL_EXPORT_C_INCLUDES := $(LOCAL_PATH)/usr/include")
    if "EXPORT_C_INCLUDES" in module.fields:
        exportedIncludeDirs = getExportedIncludes(ctx, module)
        for exportedInclude in exportedIncludeDirs:
            if exportedInclude[0] is not None:
                copyHeaders(ctx, exportedInclude[0], os.path.join(ctx.outDir, exportedInclude[1]))
            if os.path.isabs(exportedInclude[1]):
                writer.write(" \\\n\t%s" % exportedInclude[1])
            elif exportedInclude[1] != "usr/include":
                writer.write(" \\\n\t$(LOCAL_PATH)/%s" % exportedInclude[1])
    writer.write("\n")

    # Dependencies
    if "depends" in module.fields:
        raw_deps_list = module.fields["depends"].split()
        static_libs_deps = []
        shared_libs_deps = []

        while len(raw_deps_list) > 0:
            name = raw_deps_list.pop(0)
            try:
                mod = ctx.moduledb[name]
            except KeyError:
                continue
            moduleClass = mod.fields["MODULE_CLASS"]

            # follow meta-packages transitive dependencies
            if moduleClass == "META_PACKAGE":
                raw_deps_list[0:0] = mod.fields.get("depends", "").split()

            if moduleClass == "SHARED_LIBRARY" or (moduleClass == "LIBRARY" and kind == "SHARED"):
                shared_libs_deps.append(name)
            elif moduleClass == "STATIC_LIBRARY" or (moduleClass == "LIBRARY" and kind == "STATIC"):
                static_libs_deps.append("%s-static" % name)
            elif "EXPORT_LDLIBS" in mod.fields:
                libNames = mod.fields["EXPORT_LDLIBS"].split()
                for libName in ("lib" + libName[2:] for libName in libNames if libName.startswith("-l")):
                    name = mod.name + "-" + libName if len(libNames) > 1 else mod.name
                    libPathShared = None
                    libPathStatic = None
                    # Search shared/static lib path
                    for libDir in "lib", "usr/lib":
                        libPath = os.path.join(libDir, libName)
                        if os.path.exists(os.path.join(ctx.stagingDir, libPath) + ".so"):
                            libPathShared = libPath + ".so"
                        if os.path.exists(os.path.join(ctx.stagingDir, libPath) + ".a"):
                            libPathStatic = libPath + ".a"
                    if libPathStatic is not None and (libPathShared is None or kind == "STATIC"):
                        static_libs_deps.append("%s-static" % name)
                    elif libPathShared is not None and (libPathStatic is None or kind == "SHARED"):
                        shared_libs_deps.append(name)

        if static_libs_deps:
            writer.write("LOCAL_STATIC_LIBRARIES := %s\n" % " \\\n\t".join(static_libs_deps))
        if shared_libs_deps:
            writer.write("LOCAL_SHARED_LIBRARIES := %s\n" % " \\\n\t".join(shared_libs_deps))
            # make dependencies transitive
            writer.write("LOCAL_EXPORT_SHARED_LIBRARIES := $(LOCAL_SHARED_LIBRARIES)\n")


    # End of module
    writer.write("include $(PREBUILT_%s_LIBRARY)\n" % kind)
    writer.write("\n")

#===============================================================================
#===============================================================================
def processModuleAndroid(ctx, module):
    # Ignore host modules
    if module.name.startswith("host."):
        return
    moduleClass = module.fields["MODULE_CLASS"]

    if moduleClass == "SHARED_LIBRARY":
        # SHARED
        libPath = module.fields["DESTDIR"] + "/" + module.fields["MODULE_FILENAME"]
        processModuleAndroidInternal(ctx, ctx.android, module, module.name, libPath, "SHARED")
    elif moduleClass == "STATIC_LIBRARY":
        # STATIC
        libPath = module.fields["DESTDIR"] + "/" + module.fields["MODULE_FILENAME"]
        processModuleAndroidInternal(ctx, ctx.android_static, module, module.name + "-static", libPath, "STATIC")
    elif moduleClass == "LIBRARY":
        # Both SHARED and STATIC
        libPath = module.fields["DESTDIR"] + "/" + module.fields["MODULE_FILENAME"]
        processModuleAndroidInternal(ctx, ctx.android, module, module.name, libPath, "SHARED")
        if libPath.endswith(".so"):
            libPath = libPath[:-3] + ".a"
            processModuleAndroidInternal(ctx, ctx.android_static, module, module.name + "-static", libPath, "STATIC")
    elif "EXPORT_LDLIBS" in module.fields:
        # register all exported libs
        libNames = module.fields["EXPORT_LDLIBS"].split()

        for libName in libNames:
            libPathShared = None
            libPathStatic = None
            libPath = None
            modulePath = module.fields["PATH"]

            if libName.startswith("-l"):
                libName = "lib" + libName[2:]
                # Search shared/static lib path
                for libDir in "lib", "usr/lib":
                    lPath = os.path.join(libDir, libName)
                    if os.path.exists(os.path.join(ctx.stagingDir, lPath) + ".so"):
                        libPathShared = lPath + ".so"
                    if os.path.exists(os.path.join(ctx.stagingDir, lPath) + ".a"):
                        libPathStatic = lPath + ".a"
            elif libName.startswith(modulePath):
                # lib is defined by its full name (abs dir + lib name)
                if os.path.exists(modulePath):
                    relPath = os.path.relpath(libName, modulePath)
                    if relPath != ".":
                        libPath = os.path.join("usr", "lib", module.name, relPath)
                    else:
                        libPath = os.path.join("usr", "lib", module.name)
            elif libName.startswith(ctx.stagingDir):
                libPath = os.path.relpath(libName, ctx.stagingDir)
            else:
                 libPath = libName

            if libPath is not None and libPath.endswith(".so"):
                libPathShared = libPath
            elif libPath is not None and libPath.endswith(".a"):
                libPathStatic = libPath

            moduleName = module.name + "-" + libName if len(libNames) > 1 else module.name

            # Register
            if libPathShared is not None:
                # SHARED
                processModuleAndroidInternal(ctx, ctx.android, module, moduleName, libPathShared, "SHARED")
            if libPathStatic is not None:
                # STATIC
                processModuleAndroidInternal(ctx, ctx.android_static, module, moduleName + "-static", libPathStatic, "STATIC")

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
def checkTargetCcVersion(ctx):
    version = ctx.moduledb.targetVars.get("CC_VERSION", "")
    allowOlder = ctx.moduledb.targetVars.get("SDK_ALLOW_OLDER_CC", "") == "1"
    allowNewer = ctx.moduledb.targetVars.get("SDK_ALLOW_NEWER_CC", "") == "1"
    if allowOlder and allowNewer:
        # Everything allowed
        return
    if not allowOlder and not allowNewer:
        # Strict match requested
        checkTargetVar(ctx, "CC_VERSION")
    if allowOlder:
        ctx.atom.write("ifeq (\"$(call check-version,%s,$(TARGET_CC_VERSION))\",\"\")\n" % version)
        ctx.atom.write("  $(error This sdk is for TARGET_CC_VERSION <= %s)\n" % version)
        ctx.atom.write("endif\n\n")
    if allowNewer:
        ctx.atom.write("ifeq (\"$(call check-version,$(TARGET_CC_VERSION),%s)\",\"\")\n" % version)
        ctx.atom.write("  $(error This sdk is for TARGET_CC_VERSION >= %s)\n" % version)
        ctx.atom.write("endif\n\n")

#===============================================================================
#===============================================================================
def writeTargetSetupVars(ctx, name, val):
    optionalCross = ctx.moduledb.targetVars.get("SDK_OPTIONAL_CROSS", "") == "1"
    # Replace directory path referencing previous sdk or staging directory
    for dirPath in ctx.sdkDirs:
        val = val.replace(dirPath, "$(LOCAL_PATH)")
    val = val.replace(ctx.stagingDir, "$(LOCAL_PATH)")

    if name == "CROSS" and val and optionalCross:
        crossDir = os.path.dirname(val)
        ctx.setup.write("ifneq (\"$(wildcard %s)\",\"\")\n" % crossDir)

    ctx.setup.write("TARGET_%s :=" % name)
    for field in val.split():
        if field.startswith("-"):
            ctx.setup.write(" \\\n\t%s" % field)
        else:
            ctx.setup.write(" %s" % field)

    if name == "CROSS" and val and optionalCross:
        ctx.setup.write("\nendif")

    ctx.setup.write("\n\n")

#===============================================================================
# If SDK_PUBLIC_MODULES is given only those modules and their recursive public
# dependencies will be added, otherwise all build modules will be added.
# During recursive public dependency analysis, if a module has no explicit
# public/private dependencies but has some generic dependencies, a warning is
# printed and a fallback on generic dependencies is done.
#===============================================================================
def computeModuleList(ctx):
    # If a list of public modules is not given use all built modules
    publicModules = ctx.moduledb.targetVars.get("SDK_PUBLIC_MODULES", "").split()
    if not publicModules:
        return [module for module in ctx.moduledb if module.build]

    moduleList = set()
    cache = dict()

    def getDepsRecursive(module):
        if module in cache:
            return cache[module]
        depsRecursive = set()
        publicDeps = getPublicDeps(module)
        depsRecursive.update(publicDeps)
        for dep in publicDeps:
            depsRecursive.update(getDepsRecursive(ctx.moduledb[dep]))
        cache[module] = depsRecursive
        return depsRecursive

    for name in publicModules:
        module = ctx.moduledb[name]
        depsRecursive = getDepsRecursive(module)
        moduleList.add(module)
        moduleList.update(ctx.moduledb[dep] for dep in depsRecursive)

    # Keep libc if present
    if "libc" in ctx.moduledb:
        moduleList.add(ctx.moduledb["libc"])

    return moduleList

#===============================================================================
# Construct a list of private file that should not go in the sdk.
# It only list .so and .a from modules that are not explicitely listed as public
# Only module build by alchemy as 'internal' are added. Modules built as
# 'external' (like autotools) are not handled. It would required to look for the
# EXPORT_LDLIBS variable to get the name of the files. Moreover include files
# are almost impossible to filter once installed in staging directory.
#===============================================================================
def computePrivateFiles(ctx):
    privateFiles = set()
    for module in ctx.moduledb:
        if module in ctx.moduleList:
            continue
        moduleClass = module.fields["MODULE_CLASS"]
        if moduleClass in ["STATIC_LIBRARY", "SHARED_LIBRARY", "LIBRARY"]:
            destdir = module.fields["DESTDIR"]
            filename = module.fields["MODULE_FILENAME"]
            basename = os.path.splitext(filename)[0]
            privateFiles.add(os.path.join(destdir, basename + ".so"))
            privateFiles.add(os.path.join(destdir, basename + ".a"))
        copyFiles = module.fields.get("COPY_FILES", "").split()
        for copyFile in copyFiles:
            src, dst = copyFile.split(":")
            if dst.endswith("/"):
                dst += os.path.basename("src")
            privateFiles.add(dst)
    return privateFiles

def copyBuildProp(ctx):
    srcBuildProp = os.path.join(ctx.stagingDir, 'etc', 'build.prop')
    dstBuildProp = os.path.join(ctx.outDir, 'build.prop')
    ctx.addFile(srcBuildProp, dstBuildProp)

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

    # Compute list of modules to process
    publicOnly = not not ctx.moduledb.targetVars.get("SDK_PUBLIC_MODULES", "")
    ctx.moduleList = computeModuleList(ctx)
    if publicOnly:
        ctx.privateFiles = computePrivateFiles(ctx)

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
    copyStaging(ctx, ctx.stagingDir, ctx.outDir, publicOnly=publicOnly)

    # Copy content of previous sdk
    for srcDir in ctx.sdkDirs:
        copySdk(ctx, srcDir, ctx.outDir)
        with open(os.path.join(srcDir, "atom.mk")) as fin:
            ctx.atom.write(fin.read())

    # Add some TARGET_XXX variables checks to make sure that the sdk is used
    # in the correct environment
    target_elements = [
        "OS", "OS_FLAVOUR",
        "ARCH", "CPU", "CC_FLAVOUR", "TOOLCHAIN_TRIPLET",
        "LIBC", "DEFAULT_ARM_MODE", "FLOAT_ABI"
    ]
    for element_to_check in target_elements:
        checkTargetVar(ctx, element_to_check)
    checkTargetCcVersion(ctx)

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
    for module in sorted(ctx.moduleList, key=lambda m: m.name):
        processModule(ctx, module, publicOnly=publicOnly)
        if ctx.android is not None:
            processModuleAndroid(ctx, module)

    # Handle modules not already processed but whose headers are required
    for lib in ctx.headerLibs:
        module = ctx.moduledb[lib]
        if module not in ctx.moduleList:
            processModule(ctx, module, headersOnly=True, publicOnly=publicOnly)

    # Check  symlinks
    if ctx.tarFile is None:
        checkSymlinks(ctx.outDir)

    # Process custom macros
    for macro in ctx.moduledb.customMacros.values():
        ctx.atom.write("define %s\n" % macro.name)
        ctx.atom.write(macro.value)
        ctx.atom.write("\nendef\n")
        ctx.atom.write("$(call local-register-custom-macro,%s)\n" % macro.name)

    copyBuildProp(ctx)
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
