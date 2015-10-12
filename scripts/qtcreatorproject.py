#!/usr/bin/env python

import sys
import os
import shutil
import optparse
import xml.parsers
import moduledb
import xml.etree.ElementTree as ET

class Project(object):
	def __init__(self, name, modules, options):
		self.module = modules[name]
		self.modules = modules
		self.depends = [modules[dep] for dep in self.module.fields.get("depends", "").split()]
		self.depends_all = [modules[dep] for dep in self.module.fields.get("depends.all", "").split()]
		self.depends_link = [modules[dep] for dep in self.module.fields.get("depends.link", "").split()]

	def __genProjectFiles(self, prefix, options):
		filename = prefix + ".files"
		sys.stderr.write("[%s]: generating '%s'\n" % (self.module.name, filename))
		fd = open(filename, "w")
		sources = set()
		if "SRC_FILES" in self.module.fields:
			for src in self.module.fields["SRC_FILES"].split():
				fd.write("%s/%s\n" % (self.module.fields["PATH"], src))
				sources.add(os.path.splitext(os.path.basename(src))[0])
		headers = []
                # Try to guess headers by adding those with the same name as source files
		for path, dirnames, filenames in os.walk(self.module.fields["PATH"]):
			for filename in filenames:
				(prefix, ext) = os.path.splitext(os.path.basename(filename))
				if prefix in sources and ext in [".h", ".hpp", ".hh"]:
					headers.append(path + "/" + filename)
		fd.write("\n".join(headers) + "\n")
                fd.close()

	def __genProjectIncludes(self, prefix, options):
		filename = prefix + ".includes"
		sys.stderr.write("[%s]: generating '%s'\n" % (self.module.name, filename))
		includes = []
		includes.append(self.module.fields["PATH"])
		if "C_INCLUDES" in self.module.fields:
			includes += self.module.fields["C_INCLUDES"].split()
		for dep in self.depends_all:
			if "EXPORT_C_INCLUDES" in dep.fields:
				includes += dep.fields["EXPORT_C_INCLUDES"].split()
		for dep in self.depends_all:
			if "ARCHIVE_SUBDIR" in dep.fields:
				includes.append("%s/%s/%s" % (
					self.modules.targetVars["OUT_BUILD"],
					dep.name,
					dep.fields["ARCHIVE_SUBDIR"]))
                        else:
				includes.append(dep.fields["PATH"])
		# Global include directories
		includes += self.modules.targetVars["GLOBAL_C_INCLUDES"].split()
		fd = open(filename, "w")
		unique = set()
		for inc in includes:
			if not inc in unique:
				unique.add(inc)
				fd.write(inc + "\n")
                fd.close()

	def __genProjectConfig(self, prefix, options):
                config = "%s/%s/autoconf-%s.h" % (
			self.modules.targetVars["OUT_BUILD"],
			self.module.name,
			self.module.name)
		filename = prefix + ".config"
		sys.stderr.write("[%s]: generating '%s'\n" % (self.module.name, filename))
		if os.path.exists(config):
			shutil.copyfile(config, filename)
		else:
			fd = open(filename, "w")
			fd.close()

	def __genProjectCreator(self, prefix, options):
		filename = prefix + ".creator"
		sys.stderr.write("[%s]: generating '%s'\n" % (self.module.name, filename))
		fd = open(filename, "w")
		fd.close()

	def __genProjectCreatorUser(self, prefix, options):
		profile_id = None
		profile_path = os.environ["HOME"] + "/.config/QtProject/qtcreator/profiles.xml"
                if not os.path.exists(profile_path):
			sys.stderr.write("Warning: QtCreator configuration not found, " +
				"you should run qtcreator at least once before\n")
		else:
			profile = ET.parse(profile_path)
			for data in profile.findall('./data'):
				if data.findall('variable')[0].text == 'Profile.Default':
					profile_id = data.findall('value')[0].text

		if profile_id is None:
			sys.stderr.write("Warning: QtCreator Default Profile not found, " +
			    "build commands won't be available\n")

		filename = prefix + ".creator.shared"
		sys.stderr.write("[%s]: generating '%s'\n" % (self.module.name, filename))
		fd = open(filename, "w")
		fd.write('<?xml version="1.0" encoding="UTF-8"?>\n')
		fd.write('<!DOCTYPE QtCreatorProject>\n')
		fd.write('<qtcreator>\n')
		fd.write(' <data>\n')
		fd.write('  <variable>ProjectExplorer.Project.ActiveTarget</variable>\n')
		fd.write('  <value type="int">0</value>\n')
		fd.write(' </data>\n')
                fd.write(' <data>\n')
                fd.write('  <variable>ProjectExplorer.Project.EditorSettings</variable>\n')
                fd.write('  <valuemap type="QVariantMap">\n')
                fd.write('   <value type="bool" key="EditorConfiguration.UseGlobal">false</value>\n')
                fd.write('  </valuemap>\n')
                fd.write(' </data>\n')
		fd.write(' <data>\n')
		fd.write('  <variable>ProjectExplorer.Project.Target.0</variable>\n')
		fd.write('  <valuemap type="QVariantMap">\n')
		fd.write('   <value type="QString" key="ProjectExplorer.ProjectConfiguration.Id">%s</value>\n' % profile_id)
		fd.write('   <value type="int" key="ProjectExplorer.Target.ActiveBuildConfiguration">0</value>\n')
		fd.write('   <value type="int" key="ProjectExplorer.Target.ActiveDeployConfiguration">-1</value>\n')
		fd.write('   <value type="int" key="ProjectExplorer.Target.ActiveRunConfiguration">0</value>\n')
		fd.write('   <valuemap type="QVariantMap" key="ProjectExplorer.Target.BuildConfiguration.0">\n')
		fd.write('    <value type="QString" key="ProjectExplorer.BuildConfiguration.SourceDirectory">%s</value>\n' % (
			self.module.fields["PATH"]))
		fd.write('    <value type="QString" key="ProjectExplorer.BuildConfiguration.BuildDirectory">%s</value>\n' % (
			self.modules.targetVars["ALCHEMY_WORKSPACE_DIR"]))
		fd.write('    <valuemap type="QVariantMap" key="ProjectExplorer.BuildConfiguration.BuildStepList.0">\n')
		fd.write('     <valuemap type="QVariantMap" key="ProjectExplorer.BuildStepList.Step.0">\n')
		fd.write('      <value type="bool" key="ProjectExplorer.BuildStep.Enabled">true</value>\n')
		fd.write('      <value type="QString" key="ProjectExplorer.ProcessStep.Arguments">%s %s -j 4</value>\n' % (
			options.custom_build_args, self.module.name))
		fd.write('      <value type="QString" key="ProjectExplorer.ProcessStep.Command">./build.sh</value>\n')
		fd.write('      <value type="QString" key="ProjectExplorer.ProcessStep.WorkingDirectory">%{buildDir}</value>\n')
		fd.write('      <value type="QString" key="ProjectExplorer.ProjectConfiguration.DefaultDisplayName">Custom Process Step</value>\n')
		fd.write('      <value type="QString" key="ProjectExplorer.ProjectConfiguration.DisplayName"></value>\n')
		fd.write('      <value type="QString" key="ProjectExplorer.ProjectConfiguration.Id">ProjectExplorer.ProcessStep</value>\n')
		fd.write('     </valuemap>\n')
		fd.write('     <value type="int" key="ProjectExplorer.BuildStepList.StepsCount">1</value>\n')
		fd.write('     <value type="QString" key="ProjectExplorer.ProjectConfiguration.DefaultDisplayName">Build</value>\n')
		fd.write('     <value type="QString" key="ProjectExplorer.ProjectConfiguration.DisplayName"></value>\n')
		fd.write('     <value type="QString" key="ProjectExplorer.ProjectConfiguration.Id">ProjectExplorer.BuildSteps.Build</value>\n')
		fd.write('    </valuemap>\n')
		fd.write('    <valuemap type="QVariantMap" key="ProjectExplorer.BuildConfiguration.BuildStepList.1">\n')
		fd.write('     <valuemap type="QVariantMap" key="ProjectExplorer.BuildStepList.Step.0">\n')
		fd.write('      <value type="bool" key="ProjectExplorer.BuildStep.Enabled">true</value>\n')
		fd.write('      <value type="QString" key="ProjectExplorer.ProcessStep.Arguments">%s %s-dirclean</value>\n' % (
			options.custom_build_args, self.module.name))
		fd.write('      <value type="QString" key="ProjectExplorer.ProcessStep.Command">./build.sh</value>\n')
		fd.write('      <value type="QString" key="ProjectExplorer.ProcessStep.WorkingDirectory">%{buildDir}</value>\n')
		fd.write('      <value type="QString" key="ProjectExplorer.ProjectConfiguration.DefaultDisplayName">Custom Process Step</value>\n')
		fd.write('      <value type="QString" key="ProjectExplorer.ProjectConfiguration.DisplayName"></value>\n')
		fd.write('      <value type="QString" key="ProjectExplorer.ProjectConfiguration.Id">ProjectExplorer.ProcessStep</value>\n')
		fd.write('     </valuemap>\n')
		fd.write('     <value type="int" key="ProjectExplorer.BuildStepList.StepsCount">1</value>\n')
		fd.write('     <value type="QString" key="ProjectExplorer.ProjectConfiguration.DefaultDisplayName">Clean</value>\n')
		fd.write('     <value type="QString" key="ProjectExplorer.ProjectConfiguration.DisplayName"></value>\n')
		fd.write('     <value type="QString" key="ProjectExplorer.ProjectConfiguration.Id">ProjectExplorer.BuildSteps.Clean</value>\n')
		fd.write('    </valuemap>\n')
		fd.write('    <value type="int" key="ProjectExplorer.BuildConfiguration.BuildStepListCount">2</value>\n')
		fd.write('    <value type="bool" key="ProjectExplorer.BuildConfiguration.ClearSystemEnvironment">false</value>\n')
		fd.write('    <valuelist type="QVariantList" key="ProjectExplorer.BuildConfiguration.UserEnvironmentChanges"/>\n')
		fd.write('    <value type="QString" key="ProjectExplorer.ProjectConfiguration.DefaultDisplayName">Default</value>\n')
		fd.write('    <value type="QString" key="ProjectExplorer.ProjectConfiguration.DisplayName">Default</value>\n')
		fd.write('    <value type="QString" key="ProjectExplorer.ProjectConfiguration.Id">GenericProjectManager.GenericBuildConfiguration</value>\n')
		fd.write('   </valuemap>\n')
		fd.write('   <value type="int" key="ProjectExplorer.Target.BuildConfigurationCount">1</value>\n')
		fd.write('   <value type="int" key="ProjectExplorer.Target.DeployConfigurationCount">0</value>\n')

		if self.module.fields["MODULE_CLASS"] == "EXECUTABLE":
			fd.write('   <valuemap type="QVariantMap" key="ProjectExplorer.Target.RunConfiguration.0">\n')
			fd.write('    <value type="int" key="PE.EnvironmentAspect.Base">2</value>\n')
			fd.write('    <valuelist type="QVariantList" key="PE.EnvironmentAspect.Changes">\n')
			fd.write('     <value type="QString">LD_LIBRARY_PATH=out/%s-%s/staging/lib:out/%s-%s/staging/usr/lib</value>\n' % (
				self.modules.targetVars["PRODUCT"], self.modules.targetVars["PRODUCT_VARIANT"],
				self.modules.targetVars["PRODUCT"], self.modules.targetVars["PRODUCT_VARIANT"]))
			fd.write('    </valuelist>\n')
			fd.write('    <value type="QString" key="ProjectExplorer.CustomExecutableRunConfiguration.Executable">out/%s-%s/staging/usr/bin/%s</value>\n' % (
				self.modules.targetVars["PRODUCT"], self.modules.targetVars["PRODUCT_VARIANT"], self.module.name))
			fd.write('    <value type="QString" key="ProjectExplorer.CustomExecutableRunConfiguration.WorkingDirectory">%{buildDir}</value>\n')
			fd.write('    <value type="QString" key="ProjectExplorer.ProjectConfiguration.Id">ProjectExplorer.CustomExecutableRunConfiguration</value>\n')
			fd.write('   </valuemap>\n')
			fd.write('   <value type="int" key="ProjectExplorer.Target.RunConfigurationCount">1</value>\n')

		fd.write('  </valuemap>\n')
		fd.write(' </data>\n')
		fd.write(' <data>\n')
		fd.write('  <variable>ProjectExplorer.Project.TargetCount</variable>\n')
		fd.write('  <value type="int">1</value>\n')
		fd.write(' </data>\n')
		fd.write(' <data>\n')
		fd.write('  <variable>ProjectExplorer.Project.Updater.FileVersion</variable>\n')
		fd.write('  <value type="int">15</value>\n')
		fd.write(' </data>\n')
		fd.write('</qtcreator>\n')
		fd.close()

	def generate(self, options):
		prefix = "%s/qtcreator/%s-%s/%s" % (
			self.module.fields["PATH"],
			self.modules.targetVars["PRODUCT"],
			self.modules.targetVars["PRODUCT_VARIANT"],
			self.module.name)
		try:
			os.makedirs(prefix)
		except:
			pass
		self.__genProjectFiles(prefix, options)
		self.__genProjectIncludes(prefix, options)
		self.__genProjectConfig(prefix, options)
		self.__genProjectCreator(prefix, options)
		self.__genProjectCreatorUser(prefix, options)

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
		if os.path.exists(name):
			for module in modules:
				if os.path.abspath(module.fields["PATH"]) == os.path.abspath(name):
					if module.build:
						Project(module.name, modules, options).generate(options)
		elif name not in modules:
			sys.stderr.write("Error module '%s' not found:\n" % name)
		else:
			Project(name, modules, options).generate(options)

#===============================================================================
# Setup option parser and parse command line.
#===============================================================================
def parseArgs():
	# Setup parser
	usage = "usage: %prog [options] <dump-xml> <module1|dir1> <module2|dir2> ..."
	parser = optparse.OptionParser(usage=usage)

	parser.add_option("-b",
		"--custom-build-args",
		dest="custom_build_args",
		default="",
		help="Custom build arguments.")

	# Parse arguments and check validity
	(options, args) = parser.parse_args()
	if len(args) < 2:
		parser.error("Bad number of arguments")
        if not "ALCHEMY_HOME" in os.environ:
		parser.error("ALCHEMY_HOME undefined")

	return (options, args)

#===============================================================================
#===============================================================================
if __name__ == "__main__":
	main()

