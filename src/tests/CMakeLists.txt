cmake_minimum_required(VERSION 3.8)

project(test)

find_package(verilator REQUIRED HINTS $ENV{VERILATOR_ROOT})

add_executable(testbench
    main.cpp
)

verilate(
    testbench
    SOURCES
    Testbench.v
    ../flatten.v
    ../InstructionDecoder.v
    ../RegisterFile.v
    ../IntegerUnit.v
    ../Multiplier.v
    ../MemoryUnit.v
    ../BusArbiter.v
    ../MemoryArbiter.v
    ../CPU.v
    TOP_MODULE Testbench
    TRACE
    VERILATOR_ARGS
    "-DSIMULATION"
    "-DROM_PATH=\"${CMAKE_CURRENT_BINARY_DIR}/test.hex\""
    --language 1364-2005
    -Wno-UNOPTFLAT
)