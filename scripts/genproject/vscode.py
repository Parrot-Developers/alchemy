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


def _parse_flags(cflags, flags_list):
    cfp = argparse.ArgumentParser()
    for f in flags_list:
        action = 'append' if f.has_arg and f.multiple_args else \
                 'store' if f.has_arg else \
                 'store_true'
        cfp.add_argument('-{}'.format(f.name), action=action)
    x, _ = cfp.parse_known_args(cflags)

    flags = []
    for f in flags_list:
        v = x.__dict__[f.name]
        if v is None:
            continue
        if f.has_arg:
            if f.multiple_args:
                for z in v:
                    flags.extend(['-{}'.format(f.name), z])
            else:
                flags.extend(['-{}'.format(f.name), v])
        else:
            flags.append('-{}'.format(f.name))
    return flags


def _update_props(project, includes, defines):
    props = os.path.join(project.workspace_dir, '.vscode',
                         'c_cpp_properties.json')
    if not os.path.exists(props):
        logging.error(
            'file {} must exist. '.format(props) +
            'Launch VSCode, install C/C++ extension, and run the '
            '"C/C++: Edit Configurations (JSON)" task')
        sys.exit(1)

    compiler = project.get_target_var('CC')
    if not os.path.isabs(compiler):
        compiler = subprocess.check_output(
            ['which', compiler]).decode('utf-8').strip()
    cflags = project.get_target_var('GLOBAL_CFLAGS').split()
    known_flags = [
        _cflag('arch', has_arg=True),
        _cflag('isysroot', has_arg=True),
    ]
    flags = _parse_flags(cflags, known_flags)

    defs = set(defines)
    incs = set(includes)

    # Filter any "bad" defines (empty or stating with a number)
    defs = [d for d in defs if len(d) > 0 and not d[0].isdigit()]

    with open(props, 'r') as f:
        data = json.load(f)
        configs = data['configurations']
        for c in configs:
            c['includePath'] = sorted(incs)
            c['defines'] = sorted(defs)
            if flags:
                c['compilerPath'] = '{} {}'.format(compiler, ' '.join(flags))
            else:
                c['compilerPath'] = compiler
    with open(props, 'w') as f:
        json.dump(data, f, indent='\t')


def _single_task(label, command, *, default=False, reevaluate=True):
    task = {
        'label': label,
        'type': 'shell',
        'command': command,
        'problemMatcher': ['$gcc'],
    }
    if default:
        task['group'] = {'kind': 'build', 'isDefault': True}
    else:
        task['group'] = 'build'
    if not reevaluate:
        task['runOptions'] = {'reevaluateOnRerun': False}
    return task


def _gen_tasks(project, build_args, modules):
    args = ' '.join(build_args.split(' ')[:-1])  # remove trailing -A
    ncores = multiprocessing.cpu_count()
    ncores = max(ncores - 2, 1)
    tasks_path = os.path.join(project.workspace_dir, '.vscode', 'tasks.json')
    with open(tasks_path, 'w') as f:
        data = {}
        data['version'] = '2.0.0'
        tasks = list()
        data['tasks'] = tasks
        build_task = '${{workspaceFolder}}/build.sh {}'.format(args)
        if os.environ.get('TARGET_TEST', '0') == '1':
            build_task = 'env TARGET_TEST=1 ' + build_task
        tasks.append(_single_task(
            'full_build',
            '{} -t build -j{}'.format(build_task, ncores),
            default=True))
        tasks.append(_single_task(
            'clean',
            '{} -t clean -j{}'.format(build_task, ncores)))
        tasks.append(_single_task(
            'alchemy',
            '{} -A ${{input:module}}${{input:mode}}'.format(build_task),
            reevaluate=False))
        tasks.append(_single_task(
            'custom',
            '{} ${{input:any}}'.format(build_task),
            reevaluate=False))
        inputs = list()
        data['inputs'] = inputs
        inputs.append({'id': 'module',
                       'description': 'What module must we operate on',
                       'default': '',
                       'type': 'pickString',
                       'options': modules})
        inputs.append({'id': 'mode',
                       'description': 'What to do on module (empty = build)',
                       'default': ' ',
                       'type': 'pickString',
                       'options': [' ',
                                   '-clean',
                                   '-dirclean',
                                   '-codecheck',
                                   '-codeformat']})
        inputs.append({'id': 'any',
                       'description': 'Will be passed to build.sh as options',
                       'default': '',
                       'type': 'promptString'})
        json.dump(data, f, indent='\t')


def generate(project):

    if len(project.modules) > 1 and not project.options.merge:
        logging.error(
            'Multiple modules selected. Please use "-merge" option !')
        sys.exit(1)

    defines = set()
    for k, v in project.defines_c.items():
        if v:
            defines.add('{}={}'.format(k, v.replace('\\\"', '\"')))
        else:
            defines.add(k)
    for k, v in project.defines_cxx.items():
        if v:
            defines.add('{}={}'.format(k, v.replace('\\\"', '\"')))
        else:
            defines.add(k)

    _update_props(project, project.includes, defines)
    _gen_tasks(project, project.build_args, sorted(project.modules))
