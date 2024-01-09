#include <math.h>
#define VL_TIME_CONTEXT
#include "verilated.h"
#include "VBusArbiter.h"
#include "shared.h"

#define SIZE 32
#define STATION_COUNT 4
#define STATION_INDEX_SIZE 2
#define BUS_COUNT 2

int main(int argc, char *argv[]) { 
    VerilatedContext context{};
    context.commandArgs(argc, argv);

    VBusArbiter top(&context);

    top.station_ready_flat = 0;
    top.eval();

    if(top.bus_asserted_flat != 0) {
        fprintf(stderr, "Test no assertions failed\n");
        return 1;
    }

    set_bit(&top.station_ready_flat, 1);
    top.station_value_flat.at(1) = 0xCAFEBABE;
    top.eval();

    if(
        get_bit(top.bus_asserted_flat, 0) != 1 ||
        get_sub_bits(top.bus_source_flat, 0 * STATION_INDEX_SIZE, STATION_INDEX_SIZE) != 1 ||
        get_sub_bits(top.bus_value_flat, 0 * SIZE, SIZE) != 0xCAFEBABE ||
        get_bit(top.bus_asserted_flat, 1) != 0 ||
        get_bit(top.station_is_asserting_flat, 0) != 0 ||
        get_bit(top.station_is_asserting_flat, 1) != 1 ||
        get_bit(top.station_is_asserting_flat, 2) != 0 ||
        get_bit(top.station_is_asserting_flat, 3) != 0
    ) {
        fprintf(stderr, "Test single station failed\n");
        return 1;
    }

    set_bit(&top.station_ready_flat, 0);
    top.station_value_flat.at(0) = 0xFACEFEED;
    top.eval();

    if(
        get_bit(top.bus_asserted_flat, 0) != 1 ||
        get_sub_bits(top.bus_source_flat, 0 * STATION_INDEX_SIZE, STATION_INDEX_SIZE) != 0 ||
        get_sub_bits(top.bus_value_flat, 0 * SIZE, SIZE) != 0xFACEFEED ||
        get_bit(top.bus_asserted_flat, 1) != 1 ||
        get_sub_bits(top.bus_source_flat, 1 * STATION_INDEX_SIZE, STATION_INDEX_SIZE) != 1 ||
        get_sub_bits(top.bus_value_flat, 1 * SIZE, SIZE) != 0xCAFEBABE ||
        get_bit(top.station_is_asserting_flat, 0) != 1 ||
        get_bit(top.station_is_asserting_flat, 1) != 1 ||
        get_bit(top.station_is_asserting_flat, 2) != 0 ||
        get_bit(top.station_is_asserting_flat, 3) != 0
    ) {
        fprintf(stderr, "Test multiple station failed\n");
        return 1;
    }

    set_bit(&top.station_ready_flat, 2);
    top.station_value_flat.at(2) = 0xFFFFFFFF;
    top.eval();

    if(
        get_bit(top.bus_asserted_flat, 0) != 1 ||
        get_sub_bits(top.bus_source_flat, 0 * STATION_INDEX_SIZE, STATION_INDEX_SIZE) != 0 ||
        get_sub_bits(top.bus_value_flat, 0 * SIZE, SIZE) != 0xFACEFEED ||
        get_bit(top.bus_asserted_flat, 1) != 1 ||
        get_sub_bits(top.bus_source_flat, 1 * STATION_INDEX_SIZE, STATION_INDEX_SIZE) != 1 ||
        get_sub_bits(top.bus_value_flat, 1 * SIZE, SIZE) != 0xCAFEBABE ||
        get_bit(top.station_is_asserting_flat, 0) != 1 ||
        get_bit(top.station_is_asserting_flat, 1) != 1 ||
        get_bit(top.station_is_asserting_flat, 2) != 0 ||
        get_bit(top.station_is_asserting_flat, 3) != 0
    ) {
        fprintf(stderr, "Test multiple station contention failed\n");
        return 1;
    }

    return 0;
}