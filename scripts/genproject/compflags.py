import json
import logging
import os
import subprocess
import sys
import argparse
import multiprocessing


def setup_argparse(parser):
    pass


class _cflag:
    def __init__(self, name, has_arg=False, multiple_args=False):
        self.name = name
        self.has_arg = has_arg
        self.multiple_args = multiple_args


def _create_props(props):
    data = {
        "configurations": [{"name": "Linux", "intelliSenseMode": "${default}"}],
        "version": 4,
    }
    logging.warning("Creating file {}".format(props))
    os.makedirs(os.path.dirname(props), exist_ok=True)
    try:
        with open(props, "w") as f:
            json.dump(data, f, indent="\t")
    except EnvironmentError as e:
        logging.error("Failed to create file {}: {}".format(props, e))
        sys.exit(1)


def _create_compile_flags_file(project, includes, defines):
    compile_flags = os.path.join(project.outdirpath, "compile_flags.txt")
    if not os.path.exists(compile_flags):
        _create_props(compile_flags)

    compiler = project.get_target_var("CC")
    compiler_version = project.get_target_var("CC_VERSION")
    if not os.path.isabs(compiler):
        compiler = subprocess.check_output(["which", compiler]).decode("utf-8").strip()

    defs = set(defines)
    incs = list(includes)

    # Filter any "bad" defines (empty or stating with a number)
    defs = [d for d in defs if len(d) > 0 and not d[0].isdigit()]

    prefix_to_remove = "-isystem"
    for i in range(len(incs)):
        if incs[i].startswith(prefix_to_remove):
            incs[i] = incs[i].removeprefix(prefix_to_remove)
    incs = set(incs)

    with open(compile_flags, "w") as compile_flags_file:
        specific_incs = [
            f"/usr/include/x86_64-linux-gnu/c++/{compiler_version}",
            "/usr/include/x86_64-linux-gnu/",
            f"/usr/include/c++/{compiler_version}",
        ]
        for inc in incs:
            compile_flags_file.write(f"-I{inc}\n")
        for inc in specific_incs:
            compile_flags_file.write(f"-I{inc}\n")
        for d in defs:
            compile_flags_file.write(f"-D{d}\n")


def generate(project):
    if len(project.modules) > 1 and not project.options.merge:
        logging.error('Multiple modules selected. Please use "-merge" option !')
        sys.exit(1)

    defines = set()
    for k, v in project.defines_c.items():
        if v:
            defines.add("{}={}".format(k, v.replace('\\"', '"')))
        else:
            defines.add(k)
    for k, v in project.defines_cxx.items():
        if v:
            defines.add("{}={}".format(k, v.replace('\\"', '"')))
        else:
            defines.add(k)

    _create_compile_flags_file(project, project.includes, defines)
