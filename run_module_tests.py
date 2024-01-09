#!/usr/bin/env python

import os
import subprocess
import shutil

def run_command(executable, *arguments):
    try:
        subprocess.run([executable, *arguments], check=True, capture_output=True)
    except subprocess.CalledProcessError as err:
        print(err.stdout.decode('utf-8'))
        print(err.stderr.decode('utf-8'))
        raise

parent_directory = os.path.dirname(os.path.realpath(__file__))

source_directory = os.path.join(parent_directory, 'src')
build_directory = os.path.join(parent_directory, 'build', 'module_tests')

if not os.path.exists(build_directory):
    os.makedirs(build_directory)

run_command(
    shutil.which('cmake'),
    '-GNinja',
    '-S', os.path.join(source_directory, 'module_tests'),
    '-B', build_directory
)

run_command(
    shutil.which('cmake'),
    '--build',
    build_directory
)

modules = [    
    'FlattenTest',
    'BusArbiter',
    'IntegerUnit'
]

for name in modules:
    print('Running module test {}... '.format(name), end='', flush=True)

    executable_name = '{}-test.exe'.format(name) if os.name == 'nt' else '{}-test'.format(name)

    try:
        subprocess.run(
            [os.path.join(build_directory, executable_name)],
            capture_output=True,
            timeout=5,
            check=True
        )

        print('Passed')
    except subprocess.CalledProcessError as err:
        print('Failed')
        print('stdout:')
        print(err.stdout.decode('utf-8'))
        print('stderr:')
        print(err.stderr.decode('utf-8'))
        exit(1)
    except subprocess.TimeoutExpired as err:
        print('Failed (timeout)')
        print('stdout:')
        print(err.stdout.decode('utf-8'))
        print('stderr:')
        print(err.stderr.decode('utf-8'))
        exit(1)