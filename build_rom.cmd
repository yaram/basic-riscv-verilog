@echo off

clang -c -o build\rom.o src\rom.c

ld.lld -o build\rom.bin -e entry -m elf32lriscv --oformat binary build\rom.o

python create_rom_file.py