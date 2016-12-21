
import os
import logging
import xml.etree.ElementTree as ET

import template

#===============================================================================
#===============================================================================
class _TemplateHandler(object):
    def __init__(self, project):
        self.project = project

        # Search default profile id for build
        profile_id = None
        profile_path = os.path.join(os.environ["HOME"],
                ".config", "QtProject", "qtcreator", "profiles.xml")
        if not os.path.exists(profile_path):
            logging.warning("QtCreator configuration not found, "
                    "you should run qtcreator at least once before")
        else:
            profile = ET.parse(profile_path)
            for data in profile.findall("./data"):
                if data.findall("variable")[0].text == "Profile.Default":
                    profile_id = data.findall("value")[0].text

        if profile_id is None:
            logging.warning("QtCreator Default Profile not found, "
                    "build commands won't be available")

        # Replacement map
        self.replacement = {
            "PROFILE_ID": profile_id or "",
            "SOURCE_DIR": project.outdirpath,
            "BUILD_DIR": project.build_dir,
            "BUILD_CMD": project.build_cmd,
            "BUILD_ARGS": "%s %s" % (project.build_args, project.build_target),
            "CLEAN_CMD": project.build_cmd,
            "CLEAN_ARGS": "%s %s" % (project.build_args, project.clean_target),
            "RUN_ENV": project.run_env,
            "RUN_CMD": project.run_cmd,
        }

    def __call__(self, pattern):
        action = self.replacement.get(pattern, None)
        if action is None:
            logging.error("%s: unknown replacement pattern '%s'",
                    self.project.name, pattern)
            return ""
        elif callable(action):
            return action()
        else:
            return action

#===============================================================================
#===============================================================================
def _gen_project_files(project, fd):
    for source in sorted(project.sources):
        fd.write("%s\n" % source)
    for header in sorted(project.headers):
        fd.write("%s\n" % header)

#===============================================================================
#===============================================================================
def _gen_project_includes(project, fd):
    for include in sorted(project.includes):
        fd.write("%s\n" % include)

#===============================================================================
#===============================================================================
def _gen_project_config(project, fd):
    # Autoconf header files
    for autoconf_h_file in sorted(project.autoconf_h_files):
        with open(autoconf_h_file) as fin:
            fd.write(fin.read())
            fd.write("\n")

    # Defines
    defines = {}
    defines.update(project.defines_c)
    defines.update(project.defines_cxx)
    for define in sorted(defines.keys()):
        fd.write("#define %s %s\n" % (define, defines[define]))

#===============================================================================
#===============================================================================
def _gen_project_creator(project, fd):
    # Nothing to do
    pass

#===============================================================================
#===============================================================================
def setup_argparse(parser):
    # Nothing to do
    pass

#===============================================================================
#===============================================================================
def generate(project):
    _entries = [
        (project.name + ".files", _gen_project_files),
        (project.name + ".includes", _gen_project_includes),
        (project.name + ".config", _gen_project_config),
        (project.name + ".creator", _gen_project_creator),
        (project.name + ".creator.shared", "qtcreator.creator.shared.template"),
    ]

    for entry in _entries:
        outfilepath = os.path.join(project.outdirpath, entry[0])
        logging.info("%s: generating '%s'", project.name, outfilepath)
        if callable(entry[1]):
            with open(outfilepath, "w") as fd:
                entry[1](project, fd)
        else:
            infilepath = os.path.join(os.path.dirname(__file__), entry[1])
            template.expand(infilepath, outfilepath, _TemplateHandler(project))
