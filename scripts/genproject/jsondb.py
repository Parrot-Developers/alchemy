
import os
import copy
import json
import logging

CXX_EXTENSIONS = ['.cpp', '.cxx', '.cc',
                  '.CPP', '.CXX', '.CC']

C_EXTENSIONS = ['.c', '.C']

def _build_base_command_c(project):
    base_command_c = ["cc -c"]
    for include in project.includes:
        base_command_c.append("-I" + include)
    for autoconf_h_file in project.autoconf_h_files:
        base_command_c.append("-include " + autoconf_h_file)
    for define, value in project.defines_c.items():
        if value is not '':
            base_command_c.append("-D%s=%s" % (define, value))
        else:
            base_command_c.append("-D%s" % (define))
    for flag in project.cflags:
        base_command_c.append(flag)
    return base_command_c

def _build_base_command_cxx(project):
    base_command_cxx = ["c++ -c"]
    for include in project.includes:
        base_command_cxx.append("-I" + include)
    for autoconf_h_file in project.autoconf_h_files:
        base_command_cxx.append("-include " + autoconf_h_file)
    defines = {}
    defines.update(project.defines_c)
    defines.update(project.defines_cxx)
    for define, value in defines.items():
        if value is not '':
            base_command_cxx.append("-D%s=%s" % (define, value))
        else:
            base_command_cxx.append("-D%s" % (define))
    for flag in project.cxxflags:
        base_command_cxx.append(flag)
    return base_command_cxx

#===============================================================================
#===============================================================================
def setup_argparse(parser):
    # Nothing to do
    pass

#===============================================================================
#===============================================================================
def generate(project):
    outfilepath = os.path.join(project.outdirpath, "compile_commands.json")
    logging.info("%s: generating '%s'" % (project.name, outfilepath))
    base_command_c = [" ".join(_build_base_command_c(project))]
    base_command_cxx = [" ".join(_build_base_command_cxx(project))]
    db = []
    for source in project.sources:
        if os.path.splitext(source)[1] in CXX_EXTENSIONS:
            command = copy.copy(base_command_cxx)
        elif os.path.splitext(source)[1] in C_EXTENSIONS:
            command = copy.copy(base_command_c)
        else:
            logging.warning("%s: unexpected file extension %s" % (project.name, source))
            continue
        command.append("-o %s.o" % os.path.splitext(source)[0])  # Todo: get real output file path
        command.append(source)
        db.append({"directory": project.build_dir,
                   "command": " ".join(command),
                   "file": source})
    with open(outfilepath, "w") as fd:
        json.dump(db, fd, False, True, True, True, None, "\t")
