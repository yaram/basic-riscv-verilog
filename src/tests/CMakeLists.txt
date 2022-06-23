cmake_minimum_required(VERSION 3.8)

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_CURRENT_SOURCE_DIR}/")

project(test)

find_package(verilator)

add_executable(testbench
    main.cpp
)

verilate(
    testbench
    VERILATOR_ARGS "-DROM_PATH=\"${CMAKE_CURRENT_BINARY_DIR}/test.hex\""
    SOURCES
    Testbench.v
    ../CPU.v
)