cmake_minimum_required(VERSION 3.8)

project(test)

find_package(verilator REQUIRED HINTS $ENV{VERILATOR_ROOT})

add_executable(testbench
    main.cpp
)

verilate(
    testbench
    SOURCES
    Testbench.sv
    ../InstructionDecoder.sv
    ../RegisterFile.sv
    ../IntegerUnit.sv
    ../Multiplier.sv
    ../MemoryUnit.sv
    ../BusArbiter.sv
    ../MemoryArbiter.sv
    ../CPU.sv
    TOP_MODULE Testbench
    TRACE
    VERILATOR_ARGS
    "-DSIMULATION"
    "-DROM_PATH=\"${CMAKE_CURRENT_BINARY_DIR}/test.hex\""
    --language 1800-2017
    -Wno-UNOPTFLAT
)