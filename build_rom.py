#!/usr/bin/env python

import sys
import os
import subprocess

def run_command(executable, *arguments):
    subprocess.call([executable, *arguments], stdout=sys.stdout, stderr=sys.stderr, shell=True)

parent_directory = os.path.dirname(os.path.realpath(__file__))

source_directory = os.path.join(parent_directory, 'src', 'rom')
root_build_directory = os.path.join(parent_directory, 'build')
build_directory = os.path.join(root_build_directory, 'rom')

if not os.path.exists(build_directory):
    os.makedirs(build_directory)

run_command('clang', '-target', 'riscv32-unknown-unknown-elf', '-march=rv32i', '-c', '-o', os.path.join(build_directory, 'asm.o'), os.path.join(source_directory, 'asm.S'))
run_command('clang', '-target', 'riscv32-unknown-unknown-elf', '-march=rv32i', '-c', '-o', os.path.join(build_directory, 'main.o'), os.path.join(source_directory, 'main.c'))

run_command('ld.lld', '-T', os.path.join(source_directory, 'linker.ld'), '-o', os.path.join(build_directory, 'rom.elf'), '-e', 'entry', '-m', 'elf32lriscv', os.path.join(build_directory, 'asm.o'), os.path.join(build_directory, 'main.o'))
run_command('llvm-objcopy', '--output-target=binary', os.path.join(build_directory, 'rom.elf'), os.path.join(build_directory, 'rom.bin'))

with open(os.path.join(build_directory, 'rom.bin'), 'rb') as bin_file:
    rom_bytes = bin_file.read()

    with open(os.path.join(root_build_directory, 'rom.hex'), 'w') as hex_file:
        for byte in rom_bytes:
            hex_file.write('%0.2X ' % byte)