#!/usr/bin/env python

import sys
import os
import optparse
import xml.parsers
import moduledb
from xml.sax.saxutils import escape


def getRealSourceDir(src_dir):
	real_src_dir = src_dir
	(head, tail) = os.path.split(src_dir)
	if tail == "":
		(head, tail) = os.path.split(head)

	if tail.lower() == "build" or tail.lower() == "alchemy":
		real_src_dir = head

	return real_src_dir

#===============================================================================
# Get Module sources directories including generated files
#===============================================================================
def getModuleSourceDirs(self, module, build_dir):
	dirs = []

	# first get principal module source directory
	if "ARCHIVE" in module.fields:
		src_dir = build_dir + "/" + module.name + "/" + module.fields["ARCHIVE_SUBDIR"]
	else:
		src_dir = getRealSourceDir(module.fields["PATH"])

	dirs.append(src_dir)

	# get genereated source directories if exist
	if "GENERATED_SRC_FILES" in module.fields:
		for gen_dir in  module.fields["GENERATED_SRC_FILES"].split():
			gen_dir = os.path.dirname(build_dir + "/" + gen_dir)
			if gen_dir not in dirs:
				dirs.append(gen_dir)

	return dirs

#===============================================================================
#===============================================================================
class Project(object):
	def __init__(self, name, modules, options):
		self.module = modules[name]
		self.modules = modules
		self.depends = [modules[dep] for dep in self.module.fields.get("depends", "").split()]
		self.depends_all = [modules[dep] for dep in self.module.fields.get("depends.all", "").split()]
		self.depends_headers = [modules[dep] for dep in self.module.fields.get("depends.headers", "").split()]
		self.link_depends = {}

		if options.linkdeps_full:
			depends = self.depends_all + self.depends_headers
		else:
			depends = self.depends + self.depends_headers

		# populate link dependencies only for direct dependencies
		for dep in depends:
			if "ARCHIVE" in dep.fields:
				src_dir = modules.targetVars["OUT_BUILD"] + "/" + dep.name + "/" + dep.fields["ARCHIVE_SUBDIR"]
			else:
				src_dir = getRealSourceDir(dep.fields["PATH"])

			addDepend = True
			for d in self.link_depends.keys() + [self.module.fields["PATH"]]:
				if src_dir.startswith(d):
					addDepend = False
					break

			if addDepend:
				self.link_depends[src_dir] = dep

	def __genProjectFile(self, options):
		filename = self.module.fields["PATH"] + "/.project"
		sys.stderr.write("[%s]: generating '%s'\n" % (self.module.name, filename))
		fd = open(filename, "w")
		fd.write("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n")
		fd.write("<projectDescription>\n")
		fd.write("\t<name>%s</name>\n" % self.module.name)
		fd.write("\t<comment>auto-generated</comment>\n")
		fd.write("\t<projects>\n")
		fd.write("\t</projects>\n")
		fd.write("\t<buildSpec>\n")
		fd.write("\t\t<buildCommand>\n")
		fd.write("\t\t\t<name>org.eclipse.cdt.managedbuilder.core.genmakebuilder</name>\n")
		fd.write("\t\t\t<arguments>\n")
		fd.write("\t\t\t</arguments>\n")
		fd.write("\t\t</buildCommand>\n")
		fd.write("\t\t<buildCommand>\n")
		fd.write("\t\t\t<name>org.eclipse.cdt.managedbuilder.core.ScannerConfigBuilder</name>\n")
		fd.write("\t\t\t<triggers>auto,full,incremental,</triggers>\n")
		fd.write("\t\t\t<arguments>\n")
		fd.write("\t\t\t</arguments>\n")
		fd.write("\t\t</buildCommand>\n")
		fd.write("\t</buildSpec>\n")
		fd.write("\t<natures>\n")
		fd.write("\t\t<nature>org.eclipse.cdt.core.cnature</nature>\n")
		fd.write("\t\t<nature>org.eclipse.cdt.managedbuilder.core.managedBuildNature</nature>\n")
		fd.write("\t\t<nature>org.eclipse.cdt.managedbuilder.core.ScannerConfigNature</nature>\n")
		fd.write("\t\t<nature>org.eclipse.cdt.core.ccnature</nature>\n")
		fd.write("\t</natures>\n")

		if options.linkdeps and self.link_depends:
			fd.write("\t<linkedResources>\n")
			for src_dir, dep in self.link_depends.iteritems():
				# exclude libboost
				if dep.name == "libboost":
					continue

				fd.write("\t\t<link>\n")
				fd.write("\t\t\t<name>%s</name>\n" % dep.name)
				fd.write("\t\t\t<type>2</type>\n")			
				fd.write("\t\t\t<location>%s</location>\n" % src_dir)
				fd.write("\t\t</link>\n")

			fd.write("\t</linkedResources>\n")

		fd.write("</projectDescription>\n")
		fd.close()

	#===============================================================================
	# generate Symbols
	#===============================================================================
	def __genSymbols(self, fd, language):

		def genMacros(flags):
			for flag in flags.split():
				if not flag.startswith("-D"):
					continue
				if "=" in flag:
					(name, value) = flag[2:].split("=", 1)
					fd.write("\t\t\t\t\t\t\t\t\t<listOptionValue builtIn=\"false\" value=\"%s=%s\"/>\n" % (name, escape(value, {"\"": "&quot;"})))
				else:
					(name, value) = (flag[2:], "")
					fd.write("\t\t\t\t\t\t\t\t\t<listOptionValue builtIn=\"false\" value=\"%s\"/>\n" % name)

		# always add cflags
		genMacros(self.modules.targetVars.get("GLOBAL_CFLAGS", ""))
		if "CFLAGS" in self.module.fields:
			genMacros(self.module.fields["CFLAGS"])
		for dep in self.depends_all:
				genMacros(dep.fields.get("EXPORT_CFLAGS", ""))

		# add cxx flags for C++
		if language == "C++":
			genMacros(self.modules.targetVars.get("GLOBAL_CXXFLAGS", ""))
			if "CXXFLAGS" in self.module.fields:
				genMacros(self.module.fields["CXXFLAGS"])
			for dep in self.depends_all:
				genMacros(dep.fields.get("EXPORT_CXXFLAGS", ""))

	#===============================================================================
	# generate IncludeConfig File (autoconf)
	#===============================================================================
	def __genIncludeConfigFiles(self, fd):
		incFiles = []

		# add includes in incDirs
		def addFile(f):
			if f not in incFiles:
				incFiles.append(f)

		# add module dependency includes
		for dep in self.depends_all + [self.module]:
			if "CONFIG_FILES" in dep.fields:
				f = self.modules.targetVars["OUT_BUILD"] + "/" + dep.name + "/autoconf-" + dep.name + ".h"
				addFile(f)

		# write includes files
		for f in incFiles:
			fd.write("\t\t\t\t\t\t\t\t\t<listOptionValue builtIn=\"false\" value=\"%s\"/>\n" % (f))

	#===============================================================================
	# generate include dirs
	#===============================================================================
	def __genIncludes(self, fd):
		incDirs = []

		# add includes in incDirs
		def addIncludes(incPaths):
			for incPath in incPaths.split():
				if incPath not in incDirs:
					incDirs.append(incPath)

		# add global includes
		addIncludes(self.modules.targetVars.get("GLOBAL_C_INCLUDES", ""))

		# add module includes
		if "C_INCLUDES" in self.module.fields:
			addIncludes(self.module.fields["C_INCLUDES"])

		# add module dependency includes
		for dep in self.depends_all:
			addIncludes(dep.fields.get("EXPORT_C_INCLUDES", ""))

		# write includes
		for incDir in incDirs:
			fd.write("\t\t\t\t\t\t\t\t\t<listOptionValue builtIn=\"false\" value=\"%s\"/>\n" % (incDir))

	def __genBuildConfig(self, fd, options, product, variant):
		# Get toolchain build path ex:'/opt/arm-2012.03/bin'
		# Get toolchain cross prefix ex:'arm-none-linux-gnueabi-' or '' for native
		crossPath = os.path.dirname(self.modules.targetVars["CC"])
		crossPrefix = ''
		if "CROSS" in self.modules.targetVars:
			crossPrefix = os.path.basename(self.modules.targetVars["CROSS"])

		fd.write("\t\t<cconfiguration id=\"cdt.managedbuild.toolchain.gnu.cross.base.235287930\">\n")
		fd.write("\t\t\t<storageModule buildSystemId=\"org.eclipse.cdt.managedbuilder.core.configurationDataProvider\" id=\"cdt.managedbuild.toolchain.gnu.cross.base.235287930\" moduleId=\"org.eclipse.cdt.core.settings\" name=\"%s %s\">\n" % (product, variant))
		fd.write("\t\t\t\t<macros>\n")
		fd.write("\t\t\t\t\t<stringMacro name=\"TARGET_PRODUCT_VARIANT\" type=\"VALUE_TEXT\" value=\"%s\"/>\n" % variant)
		fd.write("\t\t\t\t\t<stringMacro name=\"TARGET_PRODUCT\" type=\"VALUE_TEXT\" value=\"%s\"/>\n" % product)
		fd.write("\t\t\t\t</macros>\n")
		fd.write("\t\t\t\t<externalSettings/>\n")
		fd.write("\t\t\t\t<extensions>\n")
		fd.write("\t\t\t\t\t<extension id=\"org.eclipse.cdt.core.GmakeErrorParser\" point=\"org.eclipse.cdt.core.ErrorParser\"/>\n")
		fd.write("\t\t\t\t\t<extension id=\"org.eclipse.cdt.core.CWDLocator\" point=\"org.eclipse.cdt.core.ErrorParser\"/>\n")
		fd.write("\t\t\t\t\t<extension id=\"org.eclipse.cdt.core.GCCErrorParser\" point=\"org.eclipse.cdt.core.ErrorParser\"/>\n")
		fd.write("\t\t\t\t\t<extension id=\"org.eclipse.cdt.core.GASErrorParser\" point=\"org.eclipse.cdt.core.ErrorParser\"/>\n")
		fd.write("\t\t\t\t\t<extension id=\"org.eclipse.cdt.core.GLDErrorParser\" point=\"org.eclipse.cdt.core.ErrorParser\"/>\n")
		fd.write("\t\t\t\t</extensions>\n")
		fd.write("\t\t\t</storageModule>\n")
		fd.write("\t\t\t<storageModule moduleId=\"cdtBuildSystem\" version=\"4.0.0\">\n")
		fd.write("\t\t\t\t<configuration artifactName=\"${ProjName}\" buildProperties=\"\" description=\"\" id=\"cdt.managedbuild.toolchain.gnu.cross.base.235287930\" name=\"%s %s\" parent=\"org.eclipse.cdt.build.core.emptycfg\">\n" % (product, variant))
		fd.write("\t\t\t\t\t<folderInfo id=\"cdt.managedbuild.toolchain.gnu.cross.base.235287930.445303279\" name=\"/\" resourcePath=\"\">\n")
		fd.write("\t\t\t\t\t\t<toolChain id=\"cdt.managedbuild.toolchain.gnu.cross.base.1202958509\" name=\"cdt.managedbuild.toolchain.gnu.cross.base\" superClass=\"cdt.managedbuild.toolchain.gnu.cross.base\">\n")
		fd.write("\t\t\t\t\t\t\t<option id=\"cdt.managedbuild.option.gnu.cross.prefix.1532971020\" name=\"Prefix\" superClass=\"cdt.managedbuild.option.gnu.cross.prefix\" value=\"%s\" valueType=\"string\"/>\n" % crossPrefix)
		fd.write("\t\t\t\t\t\t\t<option id=\"cdt.managedbuild.option.gnu.cross.path.1371778372\" name=\"Path\" superClass=\"cdt.managedbuild.option.gnu.cross.path\" value=\"%s\" valueType=\"string\"/>\n" % crossPath)
		fd.write("\t\t\t\t\t\t\t<targetPlatform archList=\"all\" binaryParser=\"\" id=\"cdt.managedbuild.targetPlatform.gnu.cross.1850660649\" isAbstract=\"false\" osList=\"all\" superClass=\"cdt.managedbuild.targetPlatform.gnu.cross\"/>\n")
		fd.write("\t\t\t\t\t\t\t<builder arguments=\"%s\" autoBuildTarget=\"${ProjName}\" buildPath=\"%s\" cleanBuildTarget=\"${ProjName}-clean\" command=\"${CWD}/build.sh\" enableAutoBuild=\"false\" id=\"cdt.managedbuild.builder.gnu.cross.60154042\" incrementalBuildTarget=\"${ProjName}\" keepEnvironmentInBuildfile=\"false\" managedBuildOn=\"false\" name=\"Gnu Make Builder\" superClass=\"cdt.managedbuild.builder.gnu.cross\"/>\n" % (options.custom_build_args, self.modules.targetVars["ALCHEMY_WORKSPACE_DIR"]))
		# Generate C compiler
		fd.write("\t\t\t\t\t\t\t<tool id=\"cdt.managedbuild.tool.gnu.cross.c.compiler.1213173184\" name=\"Cross GCC Compiler\" superClass=\"cdt.managedbuild.tool.gnu.cross.c.compiler\">\n")
		fd.write("\t\t\t\t\t\t\t\t<option id=\"gnu.c.compiler.option.include.paths.1976964143\" name=\"Include paths (-I)\" superClass=\"gnu.c.compiler.option.include.paths\" useByScannerDiscovery=\"false\" valueType=\"includePath\">\n")
		# generate C includes dirs
		self.__genIncludes(fd)
		fd.write("\t\t\t\t\t\t\t\t</option>\n")
		# generate C symbols
		fd.write("\t\t\t\t\t\t\t\t<option id=\"gnu.c.compiler.option.preprocessor.def.symbols.924731729\" name=\"Defined symbols (-D)\" superClass=\"gnu.c.compiler.option.preprocessor.def.symbols\" useByScannerDiscovery=\"false\" valueType=\"definedSymbols\">\n")
		self.__genSymbols(fd, "C")
		fd.write("\t\t\t\t\t\t\t\t</option>\n")
		# generate C config includes files
		fd.write("\t\t\t\t\t\t\t\t<option id=\"gnu.c.compiler.option.include.files.2029277116\" name=\"Include files (-include)\" superClass=\"gnu.c.compiler.option.include.files\" useByScannerDiscovery=\"false\" valueType=\"includeFiles\">\n")
		self.__genIncludeConfigFiles(fd)
		fd.write("\t\t\t\t\t\t\t\t</option>\n")
		fd.write("\t\t\t\t\t\t\t\t<inputType id=\"cdt.managedbuild.tool.gnu.c.compiler.input.1142186925\" superClass=\"cdt.managedbuild.tool.gnu.c.compiler.input\"/>\n")
		fd.write("\t\t\t\t\t\t\t</tool>\n")
		# Generate CPP compiler
		fd.write("\t\t\t\t\t\t\t<tool id=\"cdt.managedbuild.tool.gnu.cross.cpp.compiler.1287506518\" name=\"Cross G++ Compiler\" superClass=\"cdt.managedbuild.tool.gnu.cross.cpp.compiler\">\n")
		fd.write("\t\t\t\t\t\t\t\t<option id=\"gnu.cpp.compiler.option.include.paths.603669782\" name=\"Include paths (-I)\" superClass=\"gnu.cpp.compiler.option.include.paths\" useByScannerDiscovery=\"false\" valueType=\"includePath\">\n")
		# generate CPP includes dirs
		self.__genIncludes(fd)
		fd.write("\t\t\t\t\t\t\t\t</option>\n")
		fd.write("\t\t\t\t\t\t\t\t<option id=\"gnu.cpp.compiler.option.preprocessor.def.1041455944\" name=\"Defined symbols (-D)\" superClass=\"gnu.cpp.compiler.option.preprocessor.def\" useByScannerDiscovery=\"false\" valueType=\"definedSymbols\">\n")
		# generate CPP symbols
		self.__genSymbols(fd, "C++")
		fd.write("\t\t\t\t\t\t\t\t</option>\n")
		# generate CPP config includes files
		fd.write("\t\t\t\t\t\t\t\t<option id=\"gnu.cpp.compiler.option.include.files.661612011\" name=\"Include files (-include)\" superClass=\"gnu.cpp.compiler.option.include.files\" useByScannerDiscovery=\"false\" valueType=\"includeFiles\">\n")
		self.__genIncludeConfigFiles(fd)
		fd.write("\t\t\t\t\t\t\t\t</option>\n")
		fd.write("\t\t\t\t\t\t\t\t<inputType id=\"cdt.managedbuild.tool.gnu.cpp.compiler.input.1158160426\" superClass=\"cdt.managedbuild.tool.gnu.cpp.compiler.input\"/>\n")
		fd.write("\t\t\t\t\t\t\t</tool>\n")
		fd.write("\t\t\t\t\t\t\t<tool id=\"cdt.managedbuild.tool.gnu.cross.c.linker.1965638524\" name=\"Cross GCC Linker\" superClass=\"cdt.managedbuild.tool.gnu.cross.c.linker\"/>\n")
		fd.write("\t\t\t\t\t\t\t<tool id=\"cdt.managedbuild.tool.gnu.cross.cpp.linker.924514558\" name=\"Cross G++ Linker\" superClass=\"cdt.managedbuild.tool.gnu.cross.cpp.linker\">\n")
		fd.write("\t\t\t\t\t\t\t\t<inputType id=\"cdt.managedbuild.tool.gnu.cpp.linker.input.1315528557\" superClass=\"cdt.managedbuild.tool.gnu.cpp.linker.input\">\n")
		fd.write("\t\t\t\t\t\t\t\t\t<additionalInput kind=\"additionalinputdependency\" paths=\"$(USER_OBJS)\"/>\n")
		fd.write("\t\t\t\t\t\t\t\t\t<additionalInput kind=\"additionalinput\" paths=\"$(LIBS)\"/>\n")
		fd.write("\t\t\t\t\t\t\t\t</inputType>\n")
		fd.write("\t\t\t\t\t\t\t</tool>\n")
		fd.write("\t\t\t\t\t\t\t<tool id=\"cdt.managedbuild.tool.gnu.cross.archiver.2086349530\" name=\"Cross GCC Archiver\" superClass=\"cdt.managedbuild.tool.gnu.cross.archiver\"/>\n")
		fd.write("\t\t\t\t\t\t\t<tool id=\"cdt.managedbuild.tool.gnu.cross.assembler.665047314\" name=\"Cross GCC Assembler\" superClass=\"cdt.managedbuild.tool.gnu.cross.assembler\">\n")
		fd.write("\t\t\t\t\t\t\t\t<inputType id=\"cdt.managedbuild.tool.gnu.assembler.input.1023730334\" superClass=\"cdt.managedbuild.tool.gnu.assembler.input\"/>\n")
		fd.write("\t\t\t\t\t\t\t</tool>\n")
		fd.write("\t\t\t\t\t\t</toolChain>\n")
		fd.write("\t\t\t\t\t</folderInfo>\n")

		if options.linkdeps and self.link_depends:
			fd.write("\t\t\t\t\t<sourceEntries>\n")
			excluding = "|".join([dep.name for dep in self.link_depends.values()])
			fd.write("\t\t\t\t\t\t<entry excluding=\"%s\" flags=\"VALUE_WORKSPACE_PATH|RESOLVED\" kind=\"sourcePath\" name=\"\"/>\n" % excluding)
			for dep in self.link_depends.values():
				fd.write("\t\t\t\t\t\t<entry flags=\"VALUE_WORKSPACE_PATH|RESOLVED\" kind=\"sourcePath\" name=\"%s\"/>\n" % dep.name)
			fd.write("\t\t\t\t\t</sourceEntries>\n")

		fd.write("\t\t\t\t</configuration>\n")
		fd.write("\t\t\t</storageModule>\n")
		fd.write("\t\t\t<storageModule moduleId=\"org.eclipse.cdt.core.externalSettings\"/>\n")
		fd.write("\t\t</cconfiguration>\n")

	def __genCProjectFile(self, options):
		# get build product & variant
		product = self.modules.targetVars["PRODUCT"]
		variant = self.modules.targetVars["PRODUCT_VARIANT"]

		filename = self.module.fields["PATH"] + "/.cproject"
		sys.stderr.write("[%s]: generating '%s'\n" % (self.module.name, filename))
		fd = open(filename, "w")

		fd.write("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>\n")
		fd.write("<?fileVersion 4.0.0?><cproject storage_type_id=\"org.eclipse.cdt.core.XmlProjectDescriptionStorage\">\n")
		fd.write("\t<storageModule moduleId=\"org.eclipse.cdt.core.settings\">\n")
		# generate build configuration
		self.__genBuildConfig(fd, options, product, variant)
		fd.write("\t</storageModule>\n")
		fd.write("\t<storageModule moduleId=\"cdtBuildSystem\" version=\"4.0.0\">\n")
		fd.write("\t\t<project id=\"%s.null.1434616597\" name=\"%s\"/>\n" % (self.module.name, self.module.name))
		fd.write("\t</storageModule>\n")
		fd.write("\t<storageModule moduleId=\"org.eclipse.cdt.core.LanguageSettingsProviders\"/>\n")
		fd.write("\t<storageModule moduleId=\"refreshScope\" versionNumber=\"2\">\n")
		fd.write("\t\t<configuration configurationName=\"Default\">\n")
		fd.write("\t\t\t<resource resourceType=\"PROJECT\" workspacePath=\"/%s\"/>\n" % self.module.name)
		fd.write("\t\t</configuration>\n")
		fd.write("\t\t<configuration configurationName=\"%s %s\">\n" % (product, variant))
		fd.write("\t\t\t<resource resourceType=\"PROJECT\" workspacePath=\"/%s\"/>\n" % self.module.name)
		fd.write("\t\t</configuration>\n")
		fd.write("\t</storageModule>\n")
		fd.write("\t<storageModule moduleId=\"scannerConfiguration\"/>\n")
		fd.write("</cproject>\n")
		fd.close()

	def generate(self, options):
		self.__genProjectFile(options)
		self.__genCProjectFile(options)

#===============================================================================
#===============================================================================
def main():
	(options, args) = parseArgs()

	# Load modules from xml
	try:
		modules = moduledb.loadXml(args[0])
	except xml.parsers.expat.ExpatError as ex:
		sys.stderr.write("Error while loading '%s':\n" % args[0])
		sys.stderr.write("  %s\n" % ex)
		sys.exit(1)

	for name in args[1:]:
		if name not in modules:
			sys.stderr.write("Error module '%s' not found:\n" % name)
		else:
			Project(name, modules, options).generate(options)

#===============================================================================
# Setup option parser and parse command line.
#===============================================================================
def parseArgs():
	# Setup parser
	usage = "usage: %prog [options] <dump-xml> <module1> <module2> ..."
	parser = optparse.OptionParser(usage=usage)

	# Main option
	parser.add_option("-d",
		"--link-dependencies",
		dest="linkdeps",
		action="store_true",
		default=False,
		help="Link direct dependencies sources in project.")

	parser.add_option("-f",
		"--link-dependencies-full",
		dest="linkdeps_full",
		action="store_true",
		default=False,
		help="Link all dependencies sources in project.")

	parser.add_option("-b",
		"--custom-build-args",
		dest="custom_build_args",
		default="${TARGET_PRODUCT} ${TARGET_PRODUCT_VARIANT}",
		help="Custom build arguments.")

	# Parse arguments and check validity
	(options, args) = parser.parse_args()
	if len(args) < 2:
		parser.error("Bad number of arguments")

	# -f imply -d
	if options.linkdeps_full:
		options.linkdeps = True

	return (options, args)

#===============================================================================
#===============================================================================
if __name__ == "__main__":
	main()

