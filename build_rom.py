#!/usr/bin/env python

import sys
import os
import subprocess

def run_command(executable, *arguments):
    subprocess.call([executable, *arguments], stdout=sys.stdout, stderr=sys.stderr, shell=True)

parent_directory = os.path.dirname(os.path.realpath(__file__))

source_directory = os.path.join(parent_directory, 'src')
build_directory = os.path.join(parent_directory, 'build')

if not os.path.exists(build_directory):
    os.makedirs(build_directory)

run_command('clang', '-c', '-o', os.path.join(build_directory, 'rom.o'), os.path.join(source_directory, 'rom.S'))

run_command('ld.lld', '--section-start=.text=0', '-o', os.path.join(build_directory, 'rom.bin'), '-e', 'entry', '-m', 'elf32lriscv', '--oformat', 'binary', os.path.join(build_directory, 'rom.o'))

with open(os.path.join(build_directory, 'rom.bin'), 'rb') as bin_file:
    rom_bytes = bin_file.read()

    with open(os.path.join(build_directory, 'rom.hex'), 'w') as hex_file:
        for byte in rom_bytes:
            hex_file.write('%0.2X ' % byte)