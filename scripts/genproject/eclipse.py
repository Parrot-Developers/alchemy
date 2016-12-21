
import os
import sys
import logging
import io
from xml.sax.saxutils import escape

import template

#===============================================================================
#===============================================================================
class _TemplateHandler(object):
    def __init__(self, project):
        self.project = project

        # Get toolchain build path ex:'/opt/arm-2012.03/bin'
        toolchain_path = os.path.dirname(project.get_target_var("CC"))

        # on Mac add homebrew path to compiler path
        if sys.platform == "darwin":
            toolchain_path += ":/usr/local/bin"

        # Get toolchain cross prefix
        # ex:'arm-none-linux-gnueabi-' or '' for native
        toolchain_cross = project.get_target_var("CROSS")
        if toolchain_cross:
            toolchain_cross = os.path.basename(toolchain_cross)

        # Replacement map
        self.replacement = {
            "NAME": project.name,
            "PRODUCT": project.product,
            "VARIANT": project.variant,
            "TOOLCHAIN_PATH": toolchain_path,
            "TOOLCHAIN_CROSS": toolchain_cross,
            "BUILD_DIR": project.build_dir,
            "BUILD_CMD": "${CWD}/build.sh",
            "BUILD_ARGS": project.build_args,
            "BUILD_TARGET": project.build_target,
            "CLEAN_TARGET": project.clean_target,
            "LINKED_RESOURCES": self._gen_linked_resources,
            "SOURCE_ENTRIES": self._gen_source_entries,
            "C_INCLUDE_DIRS": self._gen_include_dirs,
            "C_DEFINES": self._gen_c_defines,
            "C_INCLUDE_FILES": self._gen_include_files,
            "CXX_INCLUDE_DIRS": self._gen_include_dirs,
            "CXX_DEFINES": self._gen_cxx_defines,
            "CXX_INCLUDE_FILES": self._gen_include_files,
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

    def _gen_linked_resources(self):
        output = io.StringIO()
        for dep in self.project.linked_resources:
            dep_path = self.project.linked_resources[dep]
            output.write("<link>\n")
            output.write("\t<name>%s</name>\n" % dep)
            output.write("\t<type>2</type>\n")
            output.write("\t<location>%s</location>\n" % dep_path)
            output.write("</link>\n")
        return output.getvalue()

    def _gen_source_entries(self):
        output = io.StringIO()
        if self.project.linked_resources:
            excluding = "|".join(self.project.linked_resources.keys())
            output.write("<entry "
                    "excluding=\"%s\" "
                    "flags=\"VALUE_WORKSPACE_PATH|RESOLVED\" "
                    "kind=\"sourcePath\" "
                    "name=\"\"/>\n" % excluding)
            for dep in self.project.linked_resources:
                output.write("<entry "
                        "flags=\"VALUE_WORKSPACE_PATH|RESOLVED\" "
                        "kind=\"sourcePath\" "
                        "name=\"%s\"/>\n" % dep)
        return output.getvalue()

    def _gen_include_dirs(self):
        output = io.StringIO()
        for include in sorted(self.project.includes):
            output.write("<listOptionValue "
                    "builtIn=\"false\" "
                    "value=\"%s\"/>\n" % include)
        return output.getvalue()

    def _gen_include_files(self):
        output = io.StringIO()
        for autoconf_h_file in sorted(self.project.autoconf_h_files):
            output.write("<listOptionValue "
                    "builtIn=\"false\" "
                    "value=\"%s\"/>\n" % autoconf_h_file)
        return output.getvalue()

    def _gen_c_defines(self):
        return self._gen_defines(self.project.defines_c)

    def _gen_cxx_defines(self):
        defines = {}
        defines.update(self.project.defines_c)
        defines.update(self.project.defines_cxx)
        return self._gen_defines(defines)

    @staticmethod
    def _gen_defines(defines):
        output = io.StringIO()
        for define in sorted(defines.keys()):
            output.write("<listOptionValue "
                    "builtIn=\"false\" "
                    "value=\"%s=%s\"/>\n" %
                    (define, escape(defines[define], {"\"": "&quot;"})))
        return output.getvalue()

#===============================================================================
#===============================================================================
def setup_argparse(parser):
    # Nothing to do
    pass

#===============================================================================
#===============================================================================
def generate(project):
    _entries = [
        (".project", "eclipse.project.template"),
        (".cproject", "eclipse.cproject.template"),
    ]

    for entry in _entries:
        outfilepath = os.path.join(project.outdirpath, entry[0])
        infilepath = os.path.join(os.path.dirname(__file__), entry[1])
        logging.info("%s: generating '%s'", project.name, outfilepath)
        template.expand(infilepath, outfilepath, _TemplateHandler(project))
