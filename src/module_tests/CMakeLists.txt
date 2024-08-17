cmake_minimum_required(VERSION 3.8)

project(test)

find_package(verilator REQUIRED HINTS $ENV{VERILATOR_ROOT})

function(generate_test MODULE)
    cmake_parse_arguments(GENERATE_TEST "" "" "VERILATOR_ARGS;SOURCES" ${ARGN})

    add_executable(${MODULE}-test
        ${MODULE}.cpp
    )

    verilate(
        ${MODULE}-test
        SOURCES
        ${GENERATE_TEST_SOURCES}
        TOP_MODULE ${MODULE}
        PREFIX V${MODULE}
        VERILATOR_ARGS
        --language 1800-2017
        -Wno-UNOPTFLAT
        ${GENERATE_TEST_VERILATOR_ARGS}
    )
endfunction()

generate_test(BusArbiter SOURCES ../BusArbiter.sv VERILATOR_ARGS -GSTATION_COUNT=4 -GBUS_COUNT=2)
generate_test(StationParameter SOURCES ../StationParameter.sv VERILATOR_ARGS -GSTATION_INDEX_SIZE=2 -GBUS_COUNT=2)
generate_test(IntegerUnit SOURCES ../StationParameter.sv ../IntegerUnit.sv VERILATOR_ARGS -GSTATION_INDEX_SIZE=2 -GBUS_COUNT=2)
generate_test(RegisterFile SOURCES ../RegisterFile.sv VERILATOR_ARGS -GREGISTER_COUNT=4)
generate_test(MemoryArbiter SOURCES ../MemoryArbiter.sv)