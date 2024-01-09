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
build_directory = os.path.join(parent_directory, 'build', 'architecture_tests')

executable_name = 'testbench.exe' if os.name == 'nt' else 'testbench'

if not os.path.exists(build_directory):
    os.makedirs(build_directory)

def run_test_set(set_name, tests):
    print('Architecture test set {}:'.format(set_name))

    for name in tests:
        print('Running architecture test {}... '.format(name), end='', flush=True)

        run_command(
            shutil.which('clang'),
            '-target', 'riscv32-unknown-unknown-elf',
            '-march=rv32im',
            '-mno-relax',
            '-I{}'.format(os.path.join(parent_directory, 'architecture_tests', 'isa', 'macros', 'scalar')),
            '-I{}'.format(os.path.join(source_directory, 'architecture_tests')),
            '-DTESTNUM=x31',
            '-c',
            '-o', os.path.join(build_directory, 'test.o'),
            os.path.join(source_directory, os.path.join(parent_directory, 'architecture_tests', 'isa', set_name, '{}.S'.format(name)))
        )

        run_command(
            shutil.which('ld.lld'),
            '-T', os.path.join(source_directory, 'architecture_tests', 'linker.ld'),
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

run_command(
    shutil.which('cmake'),
    '-GNinja',
    '-S', os.path.join(source_directory, 'architecture_tests'),
    '-B', build_directory
)

run_command(
    shutil.which('cmake'),
    '--build',
    build_directory
)

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