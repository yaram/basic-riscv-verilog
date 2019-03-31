with open('build/rom.bin', 'rb') as bin_file:
    rom_bytes = bin_file.read()

    with open('build/rom.hex', 'w') as hex_file:
        for byte in rom_bytes:
            hex_file.write('%0.2X ' % byte)