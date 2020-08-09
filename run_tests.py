#!/usr/bin/env python

import sys
import os
import subprocess
import shutil

def run_command(executable, *arguments):
    subprocess.call([executable, *arguments], stdout=sys.stdout, stderr=sys.stderr)

parent_directory = os.path.dirname(os.path.realpath(__file__))

source_directory = os.path.join(parent_directory, 'src')
build_directory = os.path.join(parent_directory, 'build')

if not os.path.exists(build_directory):
    os.makedirs(build_directory)

def run_test_set(set_name, tests):
    print('Test set {}:'.format(set_name))

    for name in tests:
        print('Running test {}... '.format(name), end='')

        run_command(
            shutil.which('clang'),
            '-target', 'riscv32-unknown-unknown-elf',
            '-march=rv32im',
            '-I{}'.format(os.path.join(parent_directory, 'tests', 'isa', 'macros', 'scalar')),
            '-I{}'.format(os.path.join(source_directory, 'tests')),
            '-DTESTNUM=x31',
            '-c',
            '-o', os.path.join(build_directory, 'test.o'),
            os.path.join(source_directory, os.path.join(parent_directory, 'tests', 'isa', set_name, '{}.S'.format(name)))
        )

        run_command(
            shutil.which('ld.lld'),
            '-T', os.path.join(source_directory, 'tests', 'linker.ld'),
            '-o', os.path.join(build_directory, 'test.elf'),
            '-e', '0x0',
            '-m', 'elf32lriscv',
            os.path.join(build_directory, 'test.o')
        )

        run_command(
            shutil.which('llvm-objcopy'),
            '--output-target=binary',
            os.path.join(build_directory, 'test.elf'),
            os.path.join(build_directory, 'test.bin')
        )

        with open(os.path.join(build_directory, 'test.bin'), 'rb') as bin_file:
            rom_bytes = bin_file.read()

            with open(os.path.join(build_directory, 'test.hex'), 'w') as hex_file:
                for byte in rom_bytes:
                    hex_file.write('%0.2X ' % byte)

        run_command(
            shutil.which('iverilog'),
            '-Wall',
            '-g2001',
            '-D', 'ROM_PATH="{}"'.format(os.path.join(build_directory, 'test.hex').replace('\\', '\\\\')),
            '-D', 'SIMULATION',
            '-o', os.path.join(build_directory, 'testbench'),
            os.path.join(source_directory, 'Testbench.v')
        )

        try:
            output = subprocess.check_output(
                [shutil.which('vvp'), '-n', os.path.join(build_directory, 'testbench')],
                timeout=5
            )

            if 'Test Passed' in output.decode('utf-8'):
                print('Passed')
            else:
                print('Failed')
        except:
                print('Failed')

run_test_set('rv32ui', [
    'simple',
    'add', 'addi',
    'and', 'andi',
    'auipc',
    'beq', 'bge', 'bgeu', 'blt', 'bltu', 'bne',
    'fence_i',
    'jal', 'jalr',
    'lb', 'lbu', 'lh', 'lhu', 'lw',
    'lui',
    'or', 'ori',
    'sb', 'sh', 'sw',
    'sll', 'slli',
    'slt', 'slti', 'sltiu', 'sltu',
    'sra', 'srai',
    'srl', 'srli',
    'sub',
    'xor',
])

run_test_set('rv32um', [
    'div', 'divu',
	'mul', 'mulh', 'mulhsu', 'mulhu',
	'rem', 'remu',
])