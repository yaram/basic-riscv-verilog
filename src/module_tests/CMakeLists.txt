cmake_minimum_required(VERSION 3.8)

project(test)

find_package(verilator REQUIRED HINTS $ENV{VERILATOR_ROOT})

function(generate_test MODULE)

    cmake_parse_arguments(GENERATE_TEST "" "VERILOG_PATH" "VERILATOR_ARGS" ${ARGN})

    if(NOT DEFINED GENERATE_TEST_VERILOG_PATH)
        set(GENERATE_TEST_VERILOG_PATH ../${MODULE}.v)
    endif()

    add_executable(${MODULE}-test
        ${MODULE}.cpp
    )

    verilate(
        ${MODULE}-test
        SOURCES
        ../flatten.v
        "${GENERATE_TEST_VERILOG_PATH}"
        TOP_MODULE ${MODULE}
        PREFIX V${MODULE}
        TRACE
        VERILATOR_ARGS
        --language 1364-2005
        -Wno-UNOPTFLAT
        ${GENERATE_TEST_VERILATOR_ARGS}
    )
endfunction()

generate_test(FlattenTest VERILOG_PATH FlattenTest.v)
generate_test(BusArbiter VERILATOR_ARGS -GSTATION_COUNT=4 -GBUS_COUNT=2)
generate_test(IntegerUnit VERILATOR_ARGS -GSTATION_INDEX_SIZE=2 -GBUS_COUNT=2)