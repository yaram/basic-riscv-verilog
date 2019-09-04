#!/usr/bin/env python

import sys
import os
import subprocess

def run_command(executable, *arguments):
    subprocess.call([executable, *arguments], stdout=sys.stdout, stderr=sys.stderr, shell=True)

parent_directory = os.path.dirname(os.path.realpath(__file__))

build_directory = os.path.join(parent_directory, 'build')

run_command('vvp', os.path.join(build_directory, 'testbench'))